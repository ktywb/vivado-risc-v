package Vivado

import org.chipsalliance.cde.config._
import freechips.rocketchip.subsystem._
import freechips.rocketchip.tile._

/**
 * Configuration fragment to enable performance counters on Rocket cores
 * This is needed for rdcycle, rdtime, rdinstret instructions to work in user mode
 */
class WithPerfCounters(nCounters: Int = 29) extends Config((site, here, up) => {
  case TilesLocated(InSubsystem) => {
    up(TilesLocated(InSubsystem), site).map {
      case tp: RocketTileAttachParams => tp.copy(tileParams = tp.tileParams.copy(
        core = tp.tileParams.core.copy(
          haveBasicCounters = true,    // Enable cycle, time, instret counters
          nPerfCounters = nCounters    // Number of additional HPM counters (0-29)
        )
      ))
      case other => other
    }
  }
})

/**
 * Configuration fragment to enable performance counters on BOOM cores
 */
class WithBoomPerfCounters(nCounters: Int = 29) extends Config((site, here, up) => {
  case TilesLocated(InSubsystem) => {
    up(TilesLocated(InSubsystem), site).map {
      case tp: boom.common.BoomTileAttachParams => tp.copy(tileParams = tp.tileParams.copy(
        core = tp.tileParams.core.copy(
          haveBasicCounters = true,
          nPerfCounters = nCounters
        )
      ))
      case other => other
    }
  }
})
