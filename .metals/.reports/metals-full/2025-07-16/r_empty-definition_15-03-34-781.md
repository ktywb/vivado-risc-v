error id: file://<WORKSPACE>/generators/partition-acc/src/main/scala/CommandRouter.scala:
file://<WORKSPACE>/generators/partition-acc/src/main/scala/CommandRouter.scala
empty definition using pc, found symbol in pc: 
empty definition using semanticdb
empty definition using fallback
non-local guesses:

offset: 3061
uri: file://<WORKSPACE>/generators/partition-acc/src/main/scala/CommandRouter.scala
text:
```scala
package partitionacc

import chisel3._
import chisel3.util._
import chisel3.{Printable}
import freechips.rocketchip.tile._
import org.chipsalliance.cde.config._
import freechips.rocketchip.diplomacy._
import freechips.rocketchip.rocket.{TLBConfig}
import freechips.rocketchip.util.DecoupledHelper
import freechips.rocketchip.rocket.constants.MemoryOpConstants
import roccaccutils._

/*
  class cache_line_dest_info extends Bundle {
    val base_addr = UInt(64.W)
    val offset = UInt(64.W)
  }
*/

class PartitionCommandRouterIO()(implicit val p: Parameters) extends Bundle {
  val rocc_in = Flipped(Decoupled(new RoCCCommand))
  val rocc_out = Decoupled(new RoCCResponse)

  val dmem_status_out = Valid(new RoCCCommand)                //                      <> l2_*_reader series in Top Module
  val sfence_out = Output(Bool())                             // sfence output signal <> l2_*_reader series in Top Module

  val partition_busy = Input(Bool())                          // Control & Status Signals <> Partition Module
  val partition_ctrl = Output(Bool())                       
  val partition_num = UInt(PartitionConsts.HashWidth.W)       
  val partition_finished = Input(Bool())            

  val cache_line_src_info = Decoupled(new StreamInfo)
  val tuple_length_src_info = Decoupled(new StreamInfo)
  val key_info_src_info = Decoupled(new StreamInfo)
  
  val cache_line_dest_info = Valid(new cache_line_dest_info)

  val bufs_completed = Input(UInt(64.W))
  val no_writes_inflight = Input(Bool())
}

class PartitionCommandRouter(cmd_queue_depth: Int)(implicit p: Parameters)
    extends Module {
  val io = IO(new PartitionCommandRouterIO)

  // 能否两次计算，第一次计算得到每个partition的大小
  // 或者先提供一组 dest addr 数组

  val FUNCT_SFENCE = 0.U
  val FUNCT_PARTITION_NUM = 1.U
  val FUNCT_CACHE_LINE_SRC_INFO = 2.U
  val FUNCT_CACHE_LINE_DEST_INFO = 3.U
  // baseaddr partition_mem_size

  val FUNCT_TUPLE_LENGTH_SRC_INFO = 4.U
  val FUNCT_KEY_INFO_SRC_INFO = 5.U
  val FUNCT_PARTITION_START = 6.U
  val FUNCT_PARTITION_STOP = 7.U
  val FUNCT_CHECK_COMPLETION = 8.U

  val cur_funct = io.rocc_in.bits.inst.funct
  val cur_rs1 = io.rocc_in.bits.rs1
  val cur_rs2 = io.rocc_in.bits.rs2

  val sfence_fire = DecoupledHelper(
    io.rocc_in.valid,
    cur_funct === FUNCT_SFENCE
  )
  io.sfence_out := sfence_fire.fire()

  io.dmem_status_out.bits <> io.rocc_in.bits
  io.dmem_status_out.valid <> io.rocc_in.fire

  val partition_ctrl_reg = RegInit(false.B)
  val partition_num_reg = RegInit(0.U(PartitionConsts.HashWidth.W))

  // to Partition Module
  io.partition_ctrl := partition_ctrl_reg
  io.partition_num := partition_num_reg
  io.cache_line_dest_info.bits.base_addr := 0.U
  io.cache_line_dest_info.bits.offset := 0.U

  // Set partition num
  val partition_num_fire = DecoupledHelper(
    io.rocc_in.valid,
    cur_funct === FUNCT_PARTITION_NUM
  )
  when(partition_num_fire.fire()) {
    partition_num_reg := cur_rs1
    PartitionLogger.accelLogInfo("Partition number set to %d\n", cur_rs1)
  }

  /* Memloader interface : cache_line_loader
  val cache@@_line_src_info_queue = Module(
    new Queue(new StreamInfo, cmd_queue_depth)
  )
  cache_line_src_info_queue.io.enq.bits.ip := cur_rs1       // addr
  cache_line_src_info_queue.io.enq.bits.isize := cur_rs2    // size
  val cache_line_src_info_fire = DecoupledHelper(
    io.rocc_in.valid,
    cur_funct === FUNCT_CACHE_LINE_SRC_INFO,
    cache_line_src_info_queue.io.enq.ready
  )
  when(cache_line_src_info_fire.fire()) {
    PartitionLogger.accelLogInfo(
      "Cache line src info set to ip: %x, isize: %d\n",
      cur_rs1,
      cur_rs2
    )
  }
  cache_line_src_info_queue.io.enq.valid := cache_line_src_info_fire.fire(
    cache_line_src_info_queue.io.enq.ready
  )
  io.cache_line_src_info <> cache_line_src_info_queue.io.deq
  // ⬆ to cache_line_loader

  val tuple_length_src_info_queue = Module(
    new Queue(new StreamInfo, cmd_queue_depth)
  )
  tuple_length_src_info_queue.io.enq.bits.ip := cur_rs1
  tuple_length_src_info_queue.io.enq.bits.isize := cur_rs2
  val tuple_length_src_info_fire = DecoupledHelper(
    io.rocc_in.valid,
    cur_funct === FUNCT_TUPLE_LENGTH_SRC_INFO,
    tuple_length_src_info_queue.io.enq.ready
  )
  when(tuple_length_src_info_fire.fire()) {
    PartitionLogger.accelLogInfo(
      "Tuple length src info set to ip: %x, isize: %d\n",
      cur_rs1,
      cur_rs2
    )
  }
  tuple_length_src_info_queue.io.enq.valid := tuple_length_src_info_fire.fire(
    tuple_length_src_info_queue.io.enq.ready
  )
  io.tuple_length_src_info <> tuple_length_src_info_queue.io.deq

  val key_info_src_info_queue = Module(
    new Queue(new StreamInfo, cmd_queue_depth)
  )
  key_info_src_info_queue.io.enq.bits.ip := cur_rs1
  key_info_src_info_queue.io.enq.bits.isize := cur_rs2
  val key_info_src_info_fire = DecoupledHelper(
    io.rocc_in.valid,
    cur_funct === FUNCT_KEY_INFO_SRC_INFO,
    key_info_src_info_queue.io.enq.ready
  )
  when(key_info_src_info_fire.fire()) {
    PartitionLogger.accelLogInfo(
      "Key info src info set to ip: %d, isize: %d\n",
      cur_rs1,
      cur_rs2
    )
  }
  key_info_src_info_queue.io.enq.valid := key_info_src_info_fire.fire(
    key_info_src_info_queue.io.enq.ready
  )
  io.key_info_src_info <> key_info_src_info_queue.io.deq

  // memwrite interface
  val cache_line_dest_info_fire = DecoupledHelper(
    io.rocc_in.valid,
    cur_funct === FUNCT_CACHE_LINE_DEST_INFO
  )
  when(cache_line_dest_info_fire.fire()) {
    io.cache_line_dest_info.valid := true.B
    io.cache_line_dest_info.bits.base_addr := cur_rs1
    io.cache_line_dest_info.bits.offset := cur_rs2
    PartitionLogger.accelLogInfo(
      "Cache line dest info set to base_addr: %d, offset: %d\n",
      cur_rs1,
      cur_rs2
    )
  }.otherwise {
    io.cache_line_dest_info.valid := false.B
  }

  // control interface
  val partition_control_fire = DecoupledHelper(
    io.rocc_in.valid,
    cur_funct === FUNCT_PARTITION_START || cur_funct === FUNCT_PARTITION_STOP
  )
  when(partition_control_fire.fire()) {
    when(cur_funct === FUNCT_PARTITION_START) {
      partition_ctrl_reg := true.B
      PartitionLogger.accelLogInfo("Partition start\n")
    }.otherwise {
      partition_ctrl_reg := false.B
      PartitionLogger.accelLogInfo("Partition stop\n")
    }
  }

  // Completion check
  val check_completion_fire = DecoupledHelper(
    io.rocc_in.valid,
    cur_funct === FUNCT_CHECK_COMPLETION,
    !io.partition_busy,
    io.partition_finished,
    io.rocc_out.ready
  )

  // rocc_out
  io.rocc_out.valid := check_completion_fire.fire()
  io.rocc_out.bits.data := io.partition_busy
  io.rocc_out.bits.rd := io.rocc_in.bits.inst.rd

  io.rocc_in.ready := sfence_fire.fire(io.rocc_in.valid) ||
                      partition_num_fire.fire(io.rocc_in.valid) ||
                      cache_line_src_info_fire.fire(io.rocc_in.valid) ||
                      cache_line_dest_info_fire.fire(io.rocc_in.valid) ||
                      tuple_length_src_info_fire.fire(io.rocc_in.valid) ||
                      key_info_src_info_fire.fire(io.rocc_in.valid) ||
                      partition_control_fire.fire(io.rocc_in.valid) ||
                      check_completion_fire.fire(io.rocc_in.valid)
}

```


#### Short summary: 

empty definition using pc, found symbol in pc: 