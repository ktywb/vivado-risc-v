error id: file://<WORKSPACE>/generators/partition-acc/src/main/scala/Logger.scala:`<none>`.
file://<WORKSPACE>/generators/partition-acc/src/main/scala/Logger.scala
empty definition using pc, found symbol in pc: `<none>`.
empty definition using semanticdb
empty definition using fallback
non-local guesses:
	 -chisel3/SynthesizePrintf.
	 -chisel3/SynthesizePrintf#
	 -chisel3/SynthesizePrintf().
	 -chisel3/util/SynthesizePrintf.
	 -chisel3/util/SynthesizePrintf#
	 -chisel3/util/SynthesizePrintf().
	 -midas/targetutils/SynthesizePrintf.
	 -midas/targetutils/SynthesizePrintf#
	 -midas/targetutils/SynthesizePrintf().
	 -roccaccutils/SynthesizePrintf.
	 -roccaccutils/SynthesizePrintf#
	 -roccaccutils/SynthesizePrintf().
	 -roccaccutils/logger/SynthesizePrintf.
	 -roccaccutils/logger/SynthesizePrintf#
	 -roccaccutils/logger/SynthesizePrintf().
	 -SynthesizePrintf.
	 -SynthesizePrintf#
	 -SynthesizePrintf().
	 -scala/Predef.SynthesizePrintf.
	 -scala/Predef.SynthesizePrintf#
	 -scala/Predef.SynthesizePrintf().
offset: 223
uri: file://<WORKSPACE>/generators/partition-acc/src/main/scala/Logger.scala
text:
```scala
// See LICENSE for license details

package partitionacc

import chisel3._
import chisel3.{Printable}
import chisel3.util._

import org.chipsalliance.cde.config.{Parameters, Field}
import midas.targetutils.{SynthesizePrintf@@}
import roccaccutils._
import roccaccutils.logger._

case object PartitionAccelPrintfSynth extends Field[Boolean](true)

object PartitionLogger extends Logger {
  val enableLogging = false

  // just print info msgs
  def logInfoImplPrintWrapper(printf: chisel3.printf.Printf)(implicit p: Parameters = Parameters.empty): chisel3.printf.Printf = {
    printf
  }

  override def logInfo(format: String, args: Bits*)(implicit p: Parameters, 
                                                   valName: freechips.rocketchip.diplomacy.ValName, 
                                                   prefix: String) : Unit = { 
    if (enableLogging) {
      val loginfo_cycles = RegInit(0.U(64.W))
      loginfo_cycles := loginfo_cycles + 1.U

      printf("[PartitionLogger] cy: %d, ", loginfo_cycles)
      printf(Printable.pack(format, args:_*))
    }
  }

  def accelLogInfo(format: String, args: Bits*)(implicit p: Parameters) : Unit = {
    val loginfo_cycles = RegInit(0.U(64.W))
    loginfo_cycles := loginfo_cycles + 1.U

    printf("[PartitionLogger] cy: %d, ", loginfo_cycles)
    printf(Printable.pack(format, args:_*))
  }

  // optionally synthesize critical msgs
  def logCriticalImplPrintWrapper(printf: chisel3.printf.Printf)(implicit p: Parameters = Parameters.empty): chisel3.printf.Printf = {
    if (p(PartitionAccelPrintfSynth)) {
      SynthesizePrintf(printf)
    } else {
      printf
    }
  }
}

```


#### Short summary: 

empty definition using pc, found symbol in pc: `<none>`.