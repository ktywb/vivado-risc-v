# Reset 逻辑修复清单

> **创建日期**: 2025-11-07  
> **目标**: 修复 variable-partition 和 variable-partition-chipyard 中的 reset 逻辑问题

---

## 修复优先级说明

- 🔴 **P0 - 致命**: 必须立即修复，影响功能正确性或导致综合失败
- 🟡 **P1 - 高**: 影响可靠性和可维护性，应尽快修复
- 🟢 **P2 - 中**: 代码规范性问题，可分批修复

---

## 📋 待修复模块列表

### 🔴 P0 - 致命问题 (3个模块)

#### 1. ❌ variable-partition-chipyard/Top.scala
- **文件路径**: `/home/name/vivado_prj/vivado-risc-v/generators/partition-chisel/src/main/scala/variable-partition-chipyard/Top.scala`
- **问题行**: 110-114
- **问题描述**: 
  - 通过组合逻辑直接驱动 `.reset` 信号
  - 违反 Chisel 最佳实践，可能导致时序违规和亚稳态
- **错误代码**:
  ```scala
  when(cmdRouter.io.reset_inst) {
    cmdRouter.reset := true.B     // ❌ 异步驱动
    accWrapper.reset := true.B
    inputLoader.reset := true.B
    outputWritter.reset := true.B
  }
  ```
- **修改方案**: 使用 `withReset()` 或同步 reset 寄存器
- **预计工作量**: 30 分钟
- **状态**: ⬜ 待修复

---

#### 2. ❌ variable-partition/TupleSplicer.scala
- **文件路径**: `/home/name/vivado_prj/vivado-risc-v/generators/partition-chisel/src/main/scala/variable-partition/TupleSplicer.scala`
- **问题行**: 33
- **问题描述**: 
  - `accumulated_info` 使用 `Reg()` 未初始化
  - 在状态机首次运行前可能为 X 态
- **错误代码**:
  ```scala
  val accumulated_info = Reg(new InfoBundle(params))  // ❌
  ```
- **修改方案**:
  ```scala
  val accumulated_info = RegInit(0.U.asTypeOf(new InfoBundle(params)))
  ```
- **预计工作量**: 5 分钟
- **状态**: ⬜ 待修复

---

#### 3. ❌ variable-partition/WriteComb.scala
- **文件路径**: `/home/name/vivado_prj/vivado-risc-v/generators/partition-chisel/src/main/scala/variable-partition/WriteComb.scala`
- **问题行**: 289 (s2_infosRead), 164 (s2_hazardHash 类型错误)
- **问题描述**: 
  - `s2_infosRead` 使用 `Wire` 但未在所有路径初始化
  - `s2_hazardHash` 声明为 `RegInit(false.B)` 但应该是 hash 类型
  - 条件 reset 逻辑不完整
- **错误代码**:
  ```scala
  val s2_hazardHash = RegInit(false.B)  // ❌ 类型错误！应该是 hash 类型
  val s2_infosRead = Wire(Vec(params.Batchs, new InfoBundle(params))) // ❌ 未初始化
  ```
- **修改方案**: 改为 RegInit 并修正类型
- **预计工作量**: 20 分钟
- **状态**: ⬜ 待修复

---

### 🟡 P1 - 高优先级 (6个模块)

#### 4. ⚠️ variable-partition/Parser.scala
- **文件路径**: `/home/name/vivado_prj/vivado-risc-v/generators/partition-chisel/src/main/scala/variable-partition/Parser.scala`
- **问题行**: 26
- **问题描述**: `tupleReg` 使用 `Reg()` 未初始化
- **错误代码**:
  ```scala
  val tupleReg = Reg(new TupleBundle(params))  // ❌
  ```
- **修改方案**:
  ```scala
  val tupleReg = RegInit(0.U.asTypeOf(new TupleBundle(params)))
  ```
- **预计工作量**: 5 分钟
- **状态**: ⬜ 待修复

---

#### 5. ⚠️ variable-partition/Dispatcher.scala
- **文件路径**: `/home/name/vivado_prj/vivado-risc-v/generators/partition-chisel/src/main/scala/variable-partition/Dispatcher.scala`
- **问题行**: 21
- **问题描述**: `s1_bits` 使用 `Reg()` 未初始化
- **错误代码**:
  ```scala
  val s1_bits = Reg(new TuplesBundle(params))  // ❌
  ```
- **修改方案**:
  ```scala
  val s1_bits = RegInit(0.U.asTypeOf(new TuplesBundle(params)))
  ```
- **预计工作量**: 5 分钟
- **状态**: ⬜ 待修复

---

#### 6. ⚠️ variable-partition/MurmurhashPart1.scala
- **文件路径**: `/home/name/vivado_prj/vivado-risc-v/generators/partition-chisel/src/main/scala/variable-partition/MurmurhashPart1.scala`
- **问题行**: 46, 49, 52, 55
- **问题描述**: 流水线寄存器 `s1_in`, `s2_in`, `s3_in`, `s4_in` 使用 `Reg()` 未初始化
- **错误代码**:
  ```scala
  val s1_in = Reg(new MurmurHashPart1Data(params))  // ❌
  val s2_in = Reg(new MurmurHashPart1Data(params))  // ❌
  val s3_in = Reg(new MurmurHashPart1Data(params))  // ❌
  val s4_in = Reg(new MurmurHashPart1Data(params))  // ❌
  ```
- **修改方案**: 全部改为 `RegInit(0.U.asTypeOf(...))`
- **预计工作量**: 10 分钟
- **状态**: ⬜ 待修复

---

#### 7. ⚠️ variable-partition/MurmurhashPart2.scala
- **文件路径**: `/home/name/vivado_prj/vivado-risc-v/generators/partition-chisel/src/main/scala/variable-partition/MurmurhashPart2.scala`
- **问题行**: 25, 28, 31, 34, 37
- **问题描述**: 流水线寄存器 `s1_in` ~ `s5_in` 使用 `Reg()` 未初始化
- **错误代码**:
  ```scala
  val s1_in = Reg(new TupleWithHashPartBundle(params))  // ❌
  // ... s2_in ~ s5_in 同样问题
  ```
- **修改方案**: 全部改为 `RegInit(0.U.asTypeOf(...))`
- **预计工作量**: 10 分钟
- **状态**: ⬜ 待修复

---

#### 8. ⚠️ variable-partition/BoundaryScanner.scala
- **文件路径**: `/home/name/vivado_prj/vivado-risc-v/generators/partition-chisel/src/main/scala/variable-partition/BoundaryScanner.scala`
- **问题行**: 83-96
- **问题描述**: 
  - `infosReg` 在 `local_reset` 中使用 for 循环清零
  - 生成大量组合逻辑，影响时序
- **当前代码**:
  ```scala
  when(io.local_reset) {
    // ...
    for (i <- 0 until BufferSize) {
      infosReg(i) := 0.U.asTypeOf(infosReg(i))  // ⚠️ 关键路径
    }
  }
  ```
- **修改方案**: 
  - 保持 `RegInit` 初始化，删除 for 循环清零
  - 或使用专用的 reset 状态机
- **预计工作量**: 15 分钟
- **状态**: ⬜ 待修复

---

#### 9. ⚠️ variable-partition/HistogramToOffset.scala
- **文件路径**: `/home/name/vivado_prj/vivado-risc-v/generators/partition-chisel/src/main/scala/variable-partition/HistogramToOffset.scala`
- **问题行**: 120-123
- **问题描述**: 
  - `s1_bits`, `s2_bits` 等改为 `RegInit` 但使用 `0.U.asTypeOf()`
  - 对于嵌套 Vec 的 Bundle，可能无法正确初始化
- **当前代码**:
  ```scala
  val s1_bits = RegInit(0.U.asTypeOf(io.in.bits))  // ⚠️ Bundle 初始化
  val s2_bits = RegInit(0.U.asTypeOf(s1_bits))
  ```
- **修改方案**: 验证 Bundle 初始化是否正确，或使用显式字段初始化
- **预计工作量**: 15 分钟
- **状态**: ⬜ 待修复

---

### 🟢 P2 - 中优先级 (2个模块)

#### 10. ℹ️ variable-partition/DataSlicer.scala
- **文件路径**: `/home/name/vivado_prj/vivado-risc-v/generators/partition-chisel/src/main/scala/variable-partition/DataSlicer.scala`
- **问题行**: 84-90, 113 (注释代码)
- **问题描述**: 
  - `s1_bits` 已使用 `RegInit`，但有注释掉的 reset 逻辑
  - 可能存在冗余代码
- **修改方案**: 
  - 确认注释代码可以删除
  - 统一 reset 策略
- **预计工作量**: 10 分钟
- **状态**: ⬜ 待修复

---

#### 11. ℹ️ variable-partition-chipyard/Wrapper.scala
- **文件路径**: `/home/name/vivado_prj/vivado-risc-v/generators/partition-chisel/src/main/scala/variable-partition-chipyard/Wrapper.scala`
- **问题行**: 32-37
- **问题描述**: 
  - 计数器 `info_src_cnt`, `data_src_cnt` 虽然使用 `RegInit`
  - 但缺少显式的全局 reset 清零路径
  - 依赖外部状态控制，可能出现死锁
- **修改方案**: 
  - 添加显式的 reset 条件检查
  - 或在顶层 wrapper reset 时确保清零
- **预计工作量**: 15 分钟
- **状态**: ⬜ 待修复

---

## 📊 修复进度统计

- **总计模块数**: 11
- **P0 (致命)**: 3 ❌
- **P1 (高)**: 6 ⚠️
- **P2 (中)**: 2 ℹ️
- **已完成**: 0 ✅
- **完成率**: 0%

---

## 🔧 修复策略

### 阶段 1: 修复 P0 致命问题 (预计 1 小时)
1. ✅ variable-partition-chipyard/Top.scala - reset 驱动方式
2. ✅ variable-partition/TupleSplicer.scala - accumulated_info 初始化
3. ✅ variable-partition/WriteComb.scala - s2_hazardHash 类型 + s2_infosRead

### 阶段 2: 修复 P1 高优先级 (预计 1 小时)
4. ✅ variable-partition/Parser.scala
5. ✅ variable-partition/Dispatcher.scala
6. ✅ variable-partition/MurmurhashPart1.scala
7. ✅ variable-partition/MurmurhashPart2.scala
8. ✅ variable-partition/BoundaryScanner.scala
9. ✅ variable-partition/HistogramToOffset.scala

### 阶段 3: 修复 P2 中优先级 (预计 30 分钟)
10. ✅ variable-partition/DataSlicer.scala
11. ✅ variable-partition-chipyard/Wrapper.scala

---

## ✅ 验证计划

### 1. 编译验证
```bash
cd /home/name/vivado_prj/vivado-risc-v
sbt compile
```

### 2. 仿真测试
```bash
# 运行现有测试套件
sbt test
```

### 3. Vivado 综合检查
```tcl
# 在 Vivado 中检查未初始化寄存器
report_drc -ruledeck default_drc
# 搜索 "LUTRAM" 和 "Uninitialized"
```

### 4. 时序分析
```tcl
# 检查 reset 路径时序
report_timing -from [get_pins -hier *reset*] -max_paths 10
```

---

## 📝 修改记录

| 日期 | 模块 | 修改人 | 状态 | 备注 |
|------|------|--------|------|------|
| 2025-11-07 | - | - | 创建清单 | 初始版本 |
|  |  |  |  |  |

---

## ⚠️ 风险提示

1. **回归测试**: 每修改一个模块，必须运行对应的测试
2. **分支管理**: 建议创建 `fix/reset-logic` 分支进行修改
3. **代码审查**: P0 和 P1 的修改应进行 peer review
4. **Vivado 版本**: 确保使用 Vivado 2022.2 进行综合验证

---

## 📚 参考资料

- [Chisel Reset 最佳实践](https://www.chisel-lang.org/chisel3/docs/explanations/reset.html)
- [FPGA Reset 设计指南](https://docs.xilinx.com/v/u/en-US/wp272)
- 项目文档: `RESET_RESET_PLAN.md`

---

**下一步**: 从 P0-1 (variable-partition-chipyard/Top.scala) 开始修复
