## 背景

按照用户要求，仅对 `generators/partition-chisel/src/main/scala/variable-partition` 与 `generators/partition-chisel/src/main/scala/variable-partition-chipyard` 目录中的模块进行检查，总结当前 reset 逻辑的缺口，并给出后续补齐建议。本版文档已结合你在 `BoundaryScanner.scala`、`DataSlicer.scala` 等文件中新增的复位代码（截至 `git status` 结果）同步更新。

---

## 模块级问题与修改建议

### 1. `BoundaryScanner.scala`
- **现状**：你已经把缓冲寄存器改成 `RegInit(VecInit(...))`，并在 `when(io.local_reset)` 分支中清零 `writePtr/readPtr/entryCount/boundaryCarry/flushMode/inputFinished`，同时遍历 `infosReg` 清空（`BoundaryScanner.scala:83-133`，见节选）。

  ```scala
  when(io.local_reset) {
    writePtr   := 0.U
    readPtr    := 0.U
    entryCount := 0.U
    boundaryCarry := 0.U
    flushMode := false.B
    inputFinished := false.B
    for (i <- 0 until BufferSize) {
      infosReg(i) := 0.U.asTypeOf(infosReg(i))
    }
  } ...
  ```

- **剩余差距**  
  1. 仍缺少 `reset_done`/`buffer_empty` 指示，顶层不知道何时可以释放 `local_reset`。  
  2. `io.infos_out.valid` 依旧直接取 `shouldOutput`，若上游在 `local_reset` 解除的同一拍继续拉高 `valid`，仍有可能输出全零。建议在复位完成之前强制 `valid := false.B`。  
  3. 可选：用 `withReset(reset.asAsyncReset || io.local_reset)` 包住整个模块，消除显式 `for` 清零带来的综合压力。

### 2. `DataSlicer.scala`
- **现状**：  
  - `infoQueue` 现在启用了 `hasFlush = true` 并与 `io.local_reset` 相连，同时在 `io.local_reset` 时把 `s1_valid`/`s1_bits` 统统清零（`DataSlicer.scala:20-111`）。  
  - `infoQueue.io.deq.ready` 也 OR 了 `io.local_reset`，能在复位中丢弃残留项。
- **剩余差距**  
  1. 同样缺少 `reset_done` 输出（例如 `!s1_valid && infoQueue.io.count === 0.U`）。  
  2. `Queue` 的 `hasFlush` 参数依赖 Chisel 版本≥3.5；需要确认当前依赖是否满足，否则应 fallback 至“dropping”实现。  
  3. 在 `local_reset` 有效期间，`io.data_in.ready`/`io.out.valid` 最好强制为 `false.B`，避免之前计算的 `s1_bits` 在 reset 后立即输出。

### 3. `WriteComb.scala`
- **现状**：只有 S1 寄存器在 `io.local_reset || init` 时清零，`s1_valid/s2_valid/s3_valid` 等控制寄存器与 hazard forward 路径仍保持旧值。
- **建议**  
  1. 在 `local_reset` 分支里一次性清除三段 valid、hazard 寄存器以及 `initCounter/drainCounter/...`，同时阻断 BRAM 写使其不会在复位过程中被旧数据覆写。  
  2. 需要 `reset_done`，例如 `!s1_valid && !s2_valid && !s3_valid && !io.busy`，供上层确认 flush 完成。  
  3. 若 `local_reset` 需要真正擦除 BRAM，可引入 `resetSweep` 状态机，顺序写零后再释放握手信号。

### 4. `ProcessEngine.scala` 及子模块
- **现状**：`ProcessEngine` 仍仅向 `WriteComb` 传递 `io.local_reset`；`TupleSplicer`、`Parser`、hash pipeline 以及前后级 FIFO 没有局部复位逻辑。
- **建议**  
  1. 为 `TupleSplicer`/`Parser` 等添加 `local_reset`，刷新其状态机寄存器与累计数据。  
  2. `ProcessEngine` 应提供 `reset_done`（`fifo0.io.count === 0.U && fifo1.io.count === 0.U && tupleSplicer.reset_done && ...`），并且在 reset 生效时对输入 `ready`/输出 `valid` 做 gating，防止旧数据冲入。

### 5. `Top.scala`
- **现状**：局部复位仍为 `localReset = RegNext((nextState === sInit) || (nextState === sBuild))` 单拍脉冲，未与下游 `reset_done` 协同。
- **建议**  
  1. 改为“保持式”复位请求：`localResetReq` 置位后等待 `boundaryScanner.reset_done && dataSlicer.reset_done && pes.forall(_.reset_done)` 才释放。  
  2. 若短期难以改所有模块接口，可先加一个 `resetStretchCounter`，在 `localResetReq` 触发后保持 N 拍，同时要求各模块在 `local_reset` 有效时强制 `valid := false.B`。

### 6. `variable-partition-chipyard/*`
- **现状**：`PartitionCommandRouter` 仍只输出 `reset_inst`；`VariablePartitionWrapper` 在接收该信号时直接调用 `accWrapper.reset := true.B` 等硬复位，无软硬同步。
- **建议**：将 `VariablePartition` 内部的握手改造透传到 wrapper（例如 `io.reset_done`），并在 RoCC 命令集里加入“等待 reset 完成”或状态寄存器，避免软件在硬件尚未 flush 完成时发起新任务。

---

## 建议的实施顺序
1. **先修下游数据面**：`BoundaryScanner`、`DataSlicer` 已完成基础清空；下一步聚焦 `WriteComb`、`ProcessEngine` 及其 FIFO。  
2. **补齐 handshake**：为每个关键模块增加 `reset_done`，确认空闲条件。  
3. **改造顶层状态机**：`Top.scala` 上等待所有 `reset_done == true` 后再从 `sInit`/-`sBuild` 过渡。  
4. **Wrapper/ROCC 接口**：在软件可见层面提供“复位完成”反馈，避免 SW 与 HW 状态不同步。

---

## 验证建议
1. **Chisel Test**：在 testbench 里反复 assert/release `local_reset`，观察 FIFO/Vec 指针是否回零，输出是否保持 invalid。  
2. **FPGA/仿真**：在运行中触发 reset，然后立即发送新任务，确认不会出现旧 tuple 被误处理。  
3. **性能检查**：复位拉长后对总体吞吐的影响有限，但需确认 `reset_done` 状态不会误判导致状态机卡死。

---

## 风险提示
- 需要新增接口/端口，可能影响大量连接（尤其 `reset_done`）。建议先在 Chisel 层改造，再统一更新 `Chipyard` wrapper。  
- 清空 BRAM/队列可能引入多拍延迟，应在时序/面积预算内评估（预计只增加少量寄存器与控制逻辑）。  
- 若使用 `withReset(reset.asAsyncReset || io.local_reset)`，请确认综合工具支持该写法的异步复位需求，并符合工程约束。

---

## 下一步
1. 按上述顺序修改源文件，逐个运行 `sbt test` 或现有回归脚本验证。  
2. 更新文档/README，说明 `local_reset`/`reset_done` 升级后的接口与使用方式。  
3. 若需要软件协同，补充 RoCC 指令集说明，让固件在 `reset_done` 前等待或轮询。
