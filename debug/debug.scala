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
      val debugWire = dontTouch(Wire(signal.cloneType))
      val debugBuf = dontTouch(Wire(signal.cloneType))
      debugBuf := signal
      debugWire := debugBuf
      debugWire.suggestName("DebugTag_" + name + "_DebugTag")
      addAttribute(debugWire, "DONT_TOUCH" -> "true", "mark_debug" -> "true", "KEEP" -> "true")
      debugWire
    }
  }
}

// object markSig{              // signal, name
//   def apply (debugSignals: Seq[(Data, String)]): Seq[Data] = {
//     debugSignals.map { case (signal, name) =>
//       // 创建一个本地的调试副本，不返回给调用者
//       val debugWire = dontTouch(Wire(signal.cloneType))
//       debugWire := signal
//       debugWire.suggestName(name)
//       addAttribute(debugWire, "DONT_TOUCH", "true")
//       addAttribute(debugWire, "KEEP", "true") 
//       addAttribute(debugWire, "mark_debug", "true")
      
//       // 返回原始信号而不是调试信号，避免调试信号传播
//       signal
//     }
//   }
  
//   // 不返回值的版本，推荐使用
//   def mark(debugSignals: Seq[(Data, String)]): Unit = {
//     debugSignals.foreach { case (signal, name) =>
//       val debugWire = dontTouch(Wire(signal.cloneType))
//       debugWire := signal
//       debugWire.suggestName(name)
//       addAttribute(debugWire, "DONT_TOUCH", "true")
//       addAttribute(debugWire, "KEEP", "true") 
//       addAttribute(debugWire, "mark_debug", "true")
//     }
//   }
// }