package partitionacc

import chisel3._
import chisel3.util._

class cache_line_dest_info extends Bundle {
  val base_addr = UInt(64.W)
  val offset = UInt(64.W)
}