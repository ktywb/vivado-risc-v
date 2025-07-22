package partitionacc

import chisel3._
import chisel3.util._

import org.chipsalliance.cde.config.{Parameters}
// import org.chipsalliance.diplomacy.lazymodule.{LazyModule}
import freechips.rocketchip.diplomacy.{LazyModule}
import freechips.rocketchip.util.{DecoupledHelper}
// import testchipip.serdes.{StreamWidener, StreamNarrower}
import testchipip.StreamNarrower
import roccaccutils._
import roccaccutils.logger._

class PartitionBundle(implicit hp: L2MemHelperParams) extends Bundle {

  // From CMD Router
  val busy = Output(Bool())
  val partition_finished = Output(Bool())
  val partition_ctrl = Input(Bool())
  val partition_num = Input(UInt(PartitionConsts.HashWidth.W))
  val cache_line_dest_info = Flipped(Valid(new cache_line_dest_info))

  // From MemLoader
  val cache_line_stream = Flipped(new MemLoaderConsumerBundle)
  val tuple_length_stream = Flipped(new MemLoaderConsumerBundle)
  val key_info_stream = Flipped(new MemLoaderConsumerBundle)

  // To MemWriter32
  val dest_info = Decoupled(new DstInfo)
  val cache_line_writes = Decoupled(new WriterBundle)
}

class Partition(implicit val p: Parameters, val hp: L2MemHelperParams)
    extends Module {
  lazy val io = IO(new PartitionBundle)

  lazy val partition = Module(new PartitionCore)

  val queue_len = 128

  val busyReg = RegInit(false.B)
  val onebit = RegInit(false.B)
  io.busy := busyReg
  // 没有 onebit 的复位逻辑？
  when(io.partition_ctrl && !onebit) {
    busyReg := true.B
    onebit := true.B
  }
  when(!io.partition_ctrl || partition.io.finish) {
    busyReg := false.B
  }

  io.partition_finished := partition.io.finish

  partition.io.clk := clock
  partition.io.nrst := !reset.asBool

  partition.io.PARTITION_NUM := io.partition_num
  partition.io.out_ready := true.B

  // 暂未实现写回逻辑
  val cache_line_dest_info_reg = RegInit(0.U.asTypeOf(new cache_line_dest_info))
  when(io.cache_line_dest_info.valid) {
    cache_line_dest_info_reg := io.cache_line_dest_info.bits
  }

  // -------------------------------------------------

  // 1. Receive data from the memloader to load_data_queue
  val cache_line_last_chunk = RegInit(false.B)
  val tuple_length_last_chunk = RegInit(false.B)
  val key_info_last_chunk = RegInit(false.B)
  val last_bit =
    cache_line_last_chunk & tuple_length_last_chunk & key_info_last_chunk & busyReg

  // cache_line_stream
  val cache_line_load_queue = Module(new Queue(new LiteralChunk, queue_len))
  dontTouch(cache_line_load_queue.io.count)
  cache_line_load_queue.io.enq.bits.chunk_data := io.cache_line_stream.output_data
  cache_line_load_queue.io.enq.bits.chunk_size_bytes := io.cache_line_stream.available_output_bytes
  cache_line_load_queue.io.enq.bits.is_final_chunk := io.cache_line_stream.output_last_chunk

  when(io.cache_line_stream.output_last_chunk) {
    cache_line_last_chunk := true.B
    PartitionLogger.accelLogInfo(
      "partition:in:valid:%x cache_line_last_chunk:%x \n",
      io.cache_line_stream.output_valid,
      cache_line_last_chunk
    )
  }
  val cache_line_fire_read = DecoupledHelper(
    io.cache_line_stream.output_valid,
    cache_line_load_queue.io.enq.ready
  )
  cache_line_load_queue.io.enq.valid := cache_line_fire_read.fire(
    cache_line_load_queue.io.enq.ready
  )
  io.cache_line_stream.output_ready := cache_line_fire_read.fire(
    io.cache_line_stream.output_valid
  )
  io.cache_line_stream.user_consumed_bytes := io.cache_line_stream.available_output_bytes

  // tuple_length_stream
  val tuple_length_load_queue = Module(new Queue(new LiteralChunk, queue_len))
  dontTouch(tuple_length_load_queue.io.count)
  tuple_length_load_queue.io.enq.bits.chunk_data := io.tuple_length_stream.output_data
  tuple_length_load_queue.io.enq.bits.chunk_size_bytes := io.tuple_length_stream.available_output_bytes
  tuple_length_load_queue.io.enq.bits.is_final_chunk := io.tuple_length_stream.output_last_chunk

  when(io.tuple_length_stream.output_last_chunk) {
    tuple_length_last_chunk := true.B
  }
  val tuple_length_fire_read = DecoupledHelper(
    io.tuple_length_stream.output_valid,
    tuple_length_load_queue.io.enq.ready
  )
  tuple_length_load_queue.io.enq.valid := tuple_length_fire_read.fire(
    tuple_length_load_queue.io.enq.ready
  )
  io.tuple_length_stream.output_ready := tuple_length_fire_read.fire(
    io.tuple_length_stream.output_valid
  )
  io.tuple_length_stream.user_consumed_bytes := io.tuple_length_stream.available_output_bytes

  // key_info_stream
  val key_info_load_queue = Module(new Queue(new LiteralChunk, queue_len))
  dontTouch(key_info_load_queue.io.count)
  key_info_load_queue.io.enq.bits.chunk_data := io.key_info_stream.output_data
  key_info_load_queue.io.enq.bits.chunk_size_bytes := io.key_info_stream.available_output_bytes
  key_info_load_queue.io.enq.bits.is_final_chunk := io.key_info_stream.output_last_chunk

  when(io.key_info_stream.output_last_chunk) {
    key_info_last_chunk := true.B
  }
  val key_info_fire_read = DecoupledHelper(
    io.key_info_stream.output_valid,
    key_info_load_queue.io.enq.ready
  )
  key_info_load_queue.io.enq.valid := key_info_fire_read.fire(
    key_info_load_queue.io.enq.ready
  )
  io.key_info_stream.output_ready := key_info_fire_read.fire(
    io.key_info_stream.output_valid
  )
  io.key_info_stream.user_consumed_bytes := io.key_info_stream.available_output_bytes




  // cache line 和 core 的连接
  partition.io.in_cache_line := cache_line_load_queue.io.deq.bits.chunk_data
  partition.io.in_cache_line_valid := cache_line_load_queue.io.deq.valid & last_bit
  cache_line_load_queue.io.deq.ready := partition.io.in_cache_line_ready & last_bit

  // tuple length 的宽度对齐和core的连接
  val tuple_length_snarrower = Module(
    new StreamNarrower(
      PartitionConsts.BUS_SZ_BITS,
      PartitionConsts.InputTupleWidth
    )
  )

  // 优化DecoupledHelper使用，避免多次fire()调用
  val tuple_length_na_fire = DecoupledHelper(
    tuple_length_load_queue.io.deq.valid,
    tuple_length_snarrower.io.in.ready
  )

  // 存储fire结果到一个值，避免重复硬件逻辑
  val tuple_length_transfer = tuple_length_na_fire.fire()
  tuple_length_load_queue.io.deq.ready := tuple_length_transfer
  tuple_length_snarrower.io.in.valid := tuple_length_transfer

  // 设置StreamNarrower输入数据
  tuple_length_snarrower.io.in.bits.data := tuple_length_load_queue.io.deq.bits.chunk_data
  tuple_length_snarrower.io.in.bits.keep := (1.U << tuple_length_load_queue.io.deq.bits.chunk_size_bytes) - 1.U
  tuple_length_snarrower.io.in.bits.last := tuple_length_load_queue.io.deq.bits.is_final_chunk

  // 将转换后的数据连接到core
  partition.io.in_tuple_length := tuple_length_snarrower.io.out.bits.data
  partition.io.in_tuple_length_valid := tuple_length_snarrower.io.out.valid & last_bit
  tuple_length_snarrower.io.out.ready := partition.io.in_tuple_length_ready & last_bit

  // 使用相同的模式优化key_info部分
  val key_info_snarrower = Module(
    new StreamNarrower(
      PartitionConsts.BUS_SZ_BITS,
      PartitionConsts.InputKeyWidth
    )
  )

  val key_info_na_fire = DecoupledHelper(
    key_info_load_queue.io.deq.valid,
    key_info_snarrower.io.in.ready
  )

  val key_info_transfer = key_info_na_fire.fire()
  key_info_load_queue.io.deq.ready := key_info_transfer
  key_info_snarrower.io.in.valid := key_info_transfer

  key_info_snarrower.io.in.bits.data := key_info_load_queue.io.deq.bits.chunk_data
  key_info_snarrower.io.in.bits.keep := (1.U << key_info_load_queue.io.deq.bits.chunk_size_bytes) - 1.U
  key_info_snarrower.io.in.bits.last := key_info_load_queue.io.deq.bits.is_final_chunk

  partition.io.in_key_info := key_info_snarrower.io.out.bits.data
  partition.io.in_key_info_valid := key_info_snarrower.io.out.valid & last_bit
  key_info_snarrower.io.out.ready := partition.io.in_key_info_ready & last_bit

  // -------------------------------------------------

  // -------------------------------------------------
  // Move logging logic from BlackBox to here
  when(partition.io.in_cache_line_valid & partition.io.in_cache_line_ready) {
    PartitionLogger.accelLogInfo(
      "partition:in:valid:%x cache_line:%x \n",
      partition.io.in_cache_line_valid,
      partition.io.in_cache_line
    )
  }
  when( partition.io.in_tuple_length_valid & partition.io.in_tuple_length_ready) {
    PartitionLogger.accelLogInfo(
      "partition:in:valid:%x tuple_length:%x \n",
      partition.io.in_tuple_length_valid,
      partition.io.in_tuple_length
    )
  }
  when(partition.io.in_key_info_valid & partition.io.in_key_info_ready) {
    PartitionLogger.accelLogInfo(
      "partition:in:valid:%x key_info:%x \n",
      partition.io.in_key_info_valid,
      partition.io.in_key_info
    )
  }
  when(partition.io.out_valid) {
    PartitionLogger.accelLogInfo(
      "partition:out:valid:%x hash:%x cache_line:%x num:%x \n",
      partition.io.out_valid,
      partition.io.out_hash,
      partition.io.out_cache_line,
      partition.io.out_num
    )
    // for (i <- 0 until PartitionConsts.TlNum) {
    //   // Calculate MSB and LSB for the i-th length value
    //   val msb = (i + 1) * PartitionConsts.LengthWidth - 1
    //   val lsb = i * PartitionConsts.LengthWidth
    //   PartitionLogger.accelLogInfo(
    //     "partition:out:length[%d]:%x\n",
    //     i.U,
    //     // Use bit slicing (msb, lsb) to extract the i-th length
    //     partition.io.out_lengths(msb, lsb)
    //   )
    // }
  }

  // ////////////////////////////////////////////////////////////////////////////
  // // tmp
  // ////////////////////////////////////////////////////////////////////////////

  io.dest_info.valid := false.B
  io.dest_info.bits := DontCare
  io.cache_line_writes.valid := false.B
  io.cache_line_writes.bits.data := 0.U
  io.cache_line_writes.bits.validbytes := 0.U
  io.cache_line_writes.bits.end_of_message := false.B

  // ////////////////////////////////////////////////////////////////////////////
  // // tmp
  // ////////////////////////////////////////////////////////////////////////////

}

class PartitionCore(implicit p: Parameters)
    extends BlackBox
    with HasBlackBoxResource {
  val io = IO(new Bundle {
    val clk = Input(Clock())
    val nrst = Input(Bool())

    val PARTITION_NUM = Input(UInt(PartitionConsts.HashWidth.W))

    val in_cache_line_valid = Input(Bool())
    val in_cache_line_ready = Output(Bool())
    val in_cache_line = Input(UInt(PartitionConsts.InputWidth.W))

    val in_tuple_length_valid = Input(Bool())
    val in_tuple_length_ready = Output(Bool())
    val in_tuple_length = Input(UInt(PartitionConsts.InputTupleWidth.W))

    val in_key_info_valid = Input(Bool())
    val in_key_info_ready = Output(Bool())
    val in_key_info = Input(UInt(PartitionConsts.InputKeyWidth.W))

    val out_ready = Input(Bool())
    val out_valid = Output(Bool())
    val out_hash = Output(UInt(PartitionConsts.HashWidth.W))
    val out_cache_line = Output(UInt(PartitionConsts.OutputWidth.W))
    val out_num = Output(UInt(PartitionConsts.LengthWidth.W))
    val out_lengths =
      Output(UInt((PartitionConsts.TlNum * PartitionConsts.LengthWidth).W))

    val error = Output(Bool())
    val runned = Output(Bool())
    val finish = Output(Bool())

  })

  // addResource("emptylogic.v")
  // addResource("partition.v")
  addResource("partition_modified.v")
}

