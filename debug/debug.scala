package debug

import chisel3._
import chisel3.experimental.{ChiselAnnotation, annotate}
import chisel3.InstanceId
import firrtl.annotations.{SingleTargetAnnotation, Target}

case class AttributeAnnotation(target: Target, description: String)
    extends SingleTargetAnnotation[Target] {
    def targets = Seq(target)
    def duplicate(n: Target) = this.copy(target = n)
    override def serialize: String =
      s"AttributeAnnotation(${target.serialize}, $description)"
  }

object addAttribute {
  def apply[T <: chisel3.InstanceId](inst: T, attribute: String, value: Any): T = {
    val stackTrace = Thread.currentThread().getStackTrace()
    if (stackTrace.length > 2) {
      val caller = stackTrace(2) 
      if(caller.getClassName != "debug.addAttribute$") {
        println(s"[debug:addAttribute] Called from: ${caller.getFileName}:${caller.getLineNumber} in ${caller.getClassName}")
      }
    }

    chisel3.experimental.annotate(new chisel3.experimental.ChiselAnnotation {
      private val valueStr = value match {
        case s: String => s"\"$s\""
        case other => other.toString
      }
      override def toFirrtl =
        new firrtl.AttributeAnnotation(inst.toTarget, s"$attribute = $valueStr")
    })
    inst
  }
  def apply[T <: chisel3.InstanceId](inst: T, attributes: (String, Any)*): T = {
    attributes.foldLeft(inst){ case (i, (attr, v)) => apply(i, attr, v) }
  }
}

object markSig{              // signal, name
  def apply (debugSignals: Seq[(Data, String)], leftTag: String= "DebugTag", rightTag: String= "DebugTag", markdebug:Boolean = true): Seq[Data] = {
    val leftBar = if(leftTag.isEmpty) "" else "_"
    val rightBar = if(rightTag.isEmpty) "" else "_"

    val stackTrace = Thread.currentThread().getStackTrace()
    if (stackTrace.length > 2) {
      val caller = stackTrace(2) 
      println(s"[debug:markSig] Called from: ${caller.getFileName}:${caller.getLineNumber} in ${caller.getClassName}")
    }
    
    debugSignals.map { case (signal, name) =>
      val debugWire = dontTouch(Wire(signal.cloneType))
      val debugBuf = dontTouch(Wire(signal.cloneType))
      debugBuf := signal
      debugWire := debugBuf
      debugWire.suggestName(leftTag + leftBar + name + rightBar + rightTag)
      if(markdebug){
        addAttribute(debugWire, "DONT_TOUCH" -> "true", "mark_debug" -> "true", "KEEP" -> "true")
      } else {
        addAttribute(debugWire, "DONT_TOUCH" -> "true", "KEEP" -> "true")
      }
      
      debugWire
    }
  }
}
