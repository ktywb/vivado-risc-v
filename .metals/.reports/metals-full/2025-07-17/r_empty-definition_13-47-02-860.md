error id: file://<WORKSPACE>/generators/partition-acc/src/main/scala/Top.scala:
file://<WORKSPACE>/generators/partition-acc/src/main/scala/Top.scala
empty definition using pc, found symbol in pc: 
empty definition using semanticdb
empty definition using fallback
non-local guesses:

offset: 3153
uri: file://<WORKSPACE>/generators/partition-acc/src/main/scala/Top.scala
text:
```scala
package partitionacc

import chisel3._
import chisel3.util._

import org.chipsalliance.cde.config.{Parameters, Field}
import freechips.rocketchip.tile._
import freechips.rocketchip.rocket.{TLBConfig}
import freechips.rocketchip.diplomacy._
// import org.chipsalliance.diplomacy.lazymodule.{LazyModule}
import freechips.rocketchip.diplomacy.{LazyModule}
import freechips.rocketchip.subsystem.{SystemBusKey}
import freechips.rocketchip.rocket.constants.MemoryOpConstants
import freechips.rocketchip.tilelink._
import roccaccutils._

case object PartitionAccelTLB extends Field[Option[TLBConfig]](None)

class PartitionAccel(opcodes: OpcodeSet)(implicit p: Parameters) 
  extends LazyRoCC(opcodes = opcodes, nPTWPorts = 4)
  with HasL2MemHelperParams {

  val roccTLNode = atlNode      //  atlNode : RoCC 加速器（LazyRoCC）中用于连接 TileLink 总线的节点

  lazy val module = new PartitionAccelImp(this)
  implicit val hp: L2MemHelperParams = L2MemHelperParams(p(SystemBusKey).beatBytes * 8)

  lazy val tlbConfig = p(PartitionAccelTLB).get
  lazy val logger = PartitionLogger

  val l2_cache_line_reader = LazyModule(new L2MemHelper(tlbConfig, printInfo="[cache_line_reader]", numOutstandingReqs=32, logger=logger))
  roccTLNode := TLWidthWidget(BUS_SZ_BYTES) := TLBuffer.chainNode(1) := l2_cache_line_reader.masterNode

  val l2_cache_line_writer = LazyModule(new L2MemHelper(tlbConfig, printInfo="[cache_line_writer]", numOutstandingReqs=64, logger=logger))
  roccTLNode := TLWidthWidget(BUS_SZ_BYTES) := TLBuffer.chainNode(1) := l2_cache_line_writer.masterNode

  val l2_tuple_length_reader = LazyModule(new L2MemHelper(tlbConfig, printInfo="[tuple_length_reader]", numOutstandingReqs=64, logger=logger))
  roccTLNode := TLWidthWidget(BUS_SZ_BYTES) := TLBuffer.chainNode(1) := l2_tuple_length_reader.masterNode

  val l2_key_info_reader = LazyModule(new L2MemHelper(tlbConfig, printInfo="[key_info_reader]", numOutstandingReqs=64, logger=logger))
  roccTLNode := TLWidthWidget(BUS_SZ_BYTES) := TLBuffer.chainNode(1) := l2_key_info_reader.masterNode
}

class PartitionAccelImp(outer: PartitionAccel)(implicit p: Parameters) 
  extends LazyRoCCModuleImp(outer)
  with MemoryOpConstants {

  val queueDepth = p(PartitionCmdQueDepth)
  implicit val hp: L2MemHelperParams = outer.hp


  io.mem.req.valid := false.B             // 内存请求有效信号
  io.mem.s1_kill := false.B               // 流水线第1阶段kill信号              // 流水线kill信号，用于取消正在执行的内存操作
  io.mem.s2_kill := false.B               // 流水线第2阶段kill信号
  io.mem.keep_clock_enabled := true.B     //  RoCC 加速器的内存接口时钟保持使能
  io.interrupt := false.B                 // 中断信号 false
  io.busy := false.B                      // 加速器忙碌状态 false
  ////////////////////////////////////////////////////////////////////////////
  // 
  ////////////////////////////////////////////////////////////////////////////

  val cmd_router = Module(new PartitionCommandRouter(queueDepth))           // 接收 CPU 通过 RoCC 指令发来的命令
  cmd_router.io.rocc_in <> io.cmd
  io.resp <> cmd_router.io.rocc_out

/*
  val streamer = Module(new Partition())                                    // Partition Module
  streamer.io.busy <> cmd_router.io.partition_busy
  strea@@mer.io.partition_ctrl <> cmd_router.io.partition_ctrl
  streamer.io.partition_num <> cmd_router.io.partition_num
  streamer.io.partition_finished <> cmd_router.io.partition_finished
  streamer.io.cache_line_dest_info <> cmd_router.io.cache_line_dest_info

  ////////////////////////////////////////////////////////////////////////////
  // 
  ////////////////////////////////////////////////////////////////////////////

  val cache_line_loader = Module(new MemLoader(memLoaderQueDepth=queueDepth, logger=outer.logger))
  outer.l2_cache_line_reader.module.io.userif <> cache_line_loader.io.l2helperUser
  cache_line_loader.io.src_info <> cmd_router.io.cache_line_src_info
  cache_line_loader.io.consumer <> streamer.io.cache_line_stream

  val tuple_length_loader = Module(new MemLoader(memLoaderQueDepth=queueDepth, logger=outer.logger))
  outer.l2_tuple_length_reader.module.io.userif <> tuple_length_loader.io.l2helperUser
  tuple_length_loader.io.src_info <> cmd_router.io.tuple_length_src_info
  tuple_length_loader.io.consumer <> streamer.io.tuple_length_stream

  val key_info_loader = Module(new MemLoader(memLoaderQueDepth=queueDepth, logger=outer.logger))
  outer.l2_key_info_reader.module.io.userif <> key_info_loader.io.l2helperUser
  key_info_loader.io.src_info <> cmd_router.io.key_info_src_info
  key_info_loader.io.consumer <> streamer.io.key_info_stream

  val cache_line_writer = Module(new MemWriter32(cmd_que_depth=queueDepth, logger=outer.logger))
  outer.l2_cache_line_writer.module.io.userif <> cache_line_writer.io.l2io
  cache_line_writer.io.decompress_dest_info <> streamer.io.dest_info
  cache_line_writer.io.memwrites_in <> streamer.io.cache_line_writes

  // Unused signals
  cmd_router.io.bufs_completed := cache_line_writer.io.bufs_completed
  cmd_router.io.no_writes_inflight := cache_line_writer.io.no_writes_inflight

  ////////////////////////////////////////////////////////////////////////////
  // Boilerplate code for l2 mem helper
  ////////////////////////////////////////////////////////////////////////////
  
  outer.l2_cache_line_reader.module.io.sfence <> cmd_router.io.sfence_out
  outer.l2_cache_line_reader.module.io.status.valid := cmd_router.io.dmem_status_out.valid
  outer.l2_cache_line_reader.module.io.status.bits := cmd_router.io.dmem_status_out.bits.status
  io.ptw(0) <> outer.l2_cache_line_reader.module.io.ptw

  outer.l2_cache_line_writer.module.io.sfence <> cmd_router.io.sfence_out
  outer.l2_cache_line_writer.module.io.status.valid := cmd_router.io.dmem_status_out.valid
  outer.l2_cache_line_writer.module.io.status.bits := cmd_router.io.dmem_status_out.bits.status
  io.ptw(1) <> outer.l2_cache_line_writer.module.io.ptw

  outer.l2_tuple_length_reader.module.io.sfence <> cmd_router.io.sfence_out
  outer.l2_tuple_length_reader.module.io.status.valid := cmd_router.io.dmem_status_out.valid
  outer.l2_tuple_length_reader.module.io.status.bits := cmd_router.io.dmem_status_out.bits.status
  io.ptw(2) <> outer.l2_tuple_length_reader.module.io.ptw

  outer.l2_key_info_reader.module.io.sfence <> cmd_router.io.sfence_out
  outer.l2_key_info_reader.module.io.status.valid := cmd_router.io.dmem_status_out.valid
  outer.l2_key_info_reader.module.io.status.bits := cmd_router.io.dmem_status_out.bits.status
  io.ptw(3) <> outer.l2_key_info_reader.module.io.ptw

}
```


#### Short summary: 

empty definition using pc, found symbol in pc: 