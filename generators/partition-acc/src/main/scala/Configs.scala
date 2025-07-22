package partitionacc

import chisel3._
import chisel3.util._

import org.chipsalliance.cde.config.{Config, Parameters, Field}
import freechips.rocketchip.tile.{BuildRoCC, OpcodeSet}
import freechips.rocketchip.rocket.{TLBConfig}
// import org.chipsalliance.diplomacy.lazymodule._
import freechips.rocketchip.diplomacy._
import roccaccutils._

case object PartitionCmdQueDepth extends Field[Int](4)

object PartitionConsts {
  val BUS_SZ_BYTES = 16     // 64 -> 16 [ for test ]
  val BUS_SZ_BYTES_LG2 = log2Ceil(BUS_SZ_BYTES)
  val BUS_SZ_BITS = BUS_SZ_BYTES * 8  // 512位

  val HashWidth = 8           // 12 -> 8
  val InputWidth = 128         // 512- > 256 [ for test ]
  val OutputWidth = 128        // 512- > 256 [ for test ]
  val LengthWidth = 8
  val TlNum = 2                // 8- > 2 [ for test ]

  val InputTupleWidth = LengthWidth * TlNum
  val InputKeyWidth = 2 * LengthWidth * TlNum
}

class WithPartitionAccel extends Config((site, here, up) => {
  case PartitionAccelTLB => Some(TLBConfig(nSets = 4, nWays = 4, nSectors = 1, nSuperpageEntries = 1))
  case BuildRoCC => up(BuildRoCC) ++ Seq(
    (p: Parameters) => {
      val acc = LazyModule(new PartitionAccel(OpcodeSet.custom0)(p)) // 响应 custom0 指令集
      acc
    }
  )
})