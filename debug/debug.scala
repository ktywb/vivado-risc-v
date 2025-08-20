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
  def apply (debugSignals: Seq[(Data, String)]): Seq[Data] = {
    debugSignals.map { case (signal, name) =>
      val debugReg = dontTouch(Wire(signal.cloneType))
      debugReg := signal
      debugReg.suggestName("DebugTag_" + name + "_DebugTag")
      // addAttribute(debugReg, "DONT_TOUCH" -> "true", "mark_debug" -> "true")
      addAttribute(debugReg, "DONT_TOUCH" -> "true")
      debugReg
    }
  }
}