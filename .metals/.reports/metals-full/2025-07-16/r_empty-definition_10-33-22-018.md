error id: file://<WORKSPACE>/generators/partition-acc/src/main/scala/Configs.scala:`<none>`.
file://<WORKSPACE>/generators/partition-acc/src/main/scala/Configs.scala
empty definition using pc, found symbol in pc: `<none>`.
empty definition using semanticdb
empty definition using fallback
non-local guesses:
	 -chisel3/OpcodeSet.
	 -chisel3/OpcodeSet#
	 -chisel3/OpcodeSet().
	 -chisel3/util/OpcodeSet.
	 -chisel3/util/OpcodeSet#
	 -chisel3/util/OpcodeSet().
	 -freechips/rocketchip/tile/OpcodeSet.
	 -freechips/rocketchip/tile/OpcodeSet#
	 -freechips/rocketchip/tile/OpcodeSet().
	 -freechips/rocketchip/diplomacy/OpcodeSet.
	 -freechips/rocketchip/diplomacy/OpcodeSet#
	 -freechips/rocketchip/diplomacy/OpcodeSet().
	 -roccaccutils/OpcodeSet.
	 -roccaccutils/OpcodeSet#
	 -roccaccutils/OpcodeSet().
	 -OpcodeSet.
	 -OpcodeSet#
	 -OpcodeSet().
	 -scala/Predef.OpcodeSet.
	 -scala/Predef.OpcodeSet#
	 -scala/Predef.OpcodeSet().
offset: 177
uri: file://<WORKSPACE>/generators/partition-acc/src/main/scala/Configs.scala
text:
```scala
package partitionacc

import chisel3._
import chisel3.util._

import org.chipsalliance.cde.config.{Config, Parameters, Field}
import freechips.rocketchip.tile.{BuildRoCC, Opcode@@Set}
import freechips.rocketchip.rocket.{TLBConfig}
// import org.chipsalliance.diplomacy.lazymodule._
import freechips.rocketchip.diplomacy._
import roccaccutils._

case object PartitionCmdQueDepth extends Field[Int](4)

object PartitionConsts {
  val BUS_SZ_BYTES = 64
  val BUS_SZ_BYTES_LG2 = log2Ceil(BUS_SZ_BYTES)
  val BUS_SZ_BITS = BUS_SZ_BYTES * 8

  val HashWidth = 12
  val InputWidth = 512
  val OutputWidth = 512
  val LengthWidth = 8
  val TlNum = 8

  val InputTupleWidth = LengthWidth * TlNum
  val InputKeyWidth = 2 * LengthWidth * TlNum
}

class WithPartitionAccel extends Config((site, here, up) => {
  case PartitionAccelTLB => Some(TLBConfig(nSets = 4, nWays = 4, nSectors = 1, nSuperpageEntries = 1))
  case BuildRoCC => up(BuildRoCC) ++ Seq(
    (p: Parameters) => {
      val acc = LazyModule(new PartitionAccel(OpcodeSet.custom0)(p))
      acc
    }
  )
})
```


#### Short summary: 

empty definition using pc, found symbol in pc: `<none>`.