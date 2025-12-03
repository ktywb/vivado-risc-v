# ILA Cascade Configuration

## 概述

支持使用可配置个数的ILA（Integrated Logic Analyzer）级联，以获得更长的**连续采样时间**。

## ⚠️ 级联工作原理（修正版）

### 正确的级联方式：
**所有ILA连接相同的信号探针**，通过TRIG_OUT/TRIG_IN形成时间上的连续采样。

```
时间轴：  [ILA0: 8192 samples] → [ILA1: 8192 samples] → [ILA2: 8192 samples]
          ↑触发条件              ↑ILA0满后自动触发      ↑ILA1满后自动触发
信号：    所有探针               所有探针               所有探针
```

### 工作流程：
1. **触发检测**：ILA0监测触发条件（如FLAG信号）
2. **第一阶段采样**：ILA0采样8192个时钟周期
3. **自动级联**：ILA0满后，发送TRIG_OUT信号到ILA1的TRIG_IN
4. **第二阶段采样**：ILA1立即开始采样下一个8192周期
5. **继续级联**：ILA1满后触发ILA2（如果有）
6. **数据合并**：读取时按顺序合并ILA0→ILA1→ILA2的数据

### 关键特点：
- ✅ **相同探针**：所有ILA监测相同的信号
- ✅ **连续时间**：无采样间隙，时间连续
- ✅ **自动触发**：级联触发无需人工干预
- ✅ **数据完整**：可观察完整的长时间序列事件

## 配置参数

### ILA_CASCADE_NUM

控制级联的ILA核心数量。

- **取值范围**: 1-3
- **默认值**: 1
- **单个ILA深度**: 8192 samples
- **总采样深度**: `8192 × ILA_CASCADE_NUM` (连续)

### 级联配置示例

| ILA数量 | 连续采样深度 | 适用场景 |
|---------|--------------|----------|
| 1 | 8,192 cycles | 快速调试，短时间观察 |
| 2 | 16,384 cycles | 中等时长事件捕获（如你的256KB数据处理） |
| 3 | 24,576 cycles | 长时间序列分析（复杂状态机转换） |

## 使用方法

### 方法1：在Makefile中设置（推荐）

编辑 `Makefile` 第12行：

```makefile
ILA_CASCADE_NUM ?= 2  # 修改为所需的ILA数量
```

然后正常构建：

```bash
make CONFIG=rocket64b1_partition_debug impl
```

### 方法2：命令行参数

```bash
make CONFIG=rocket64b1_partition_debug ILA_CASCADE_NUM=2 impl
```

### 方法3：环境变量

```bash
export ILA_CASCADE_NUM=3
make CONFIG=rocket64b1_partition_debug impl
```

## 级联连接拓扑

```
          触发条件
             ↓
    ┌───────────────┐
    │   u_ila_0     │  第1个8192 samples
    │  (所有探针)   │
    └───────┬───────┘
            │ TRIG_OUT (ILA0满)
            ↓ TRIG_IN
    ┌───────────────┐
    │   u_ila_1     │  第2个8192 samples
    │  (所有探针)   │
    └───────┬───────┘
            │ TRIG_OUT (ILA1满)
            ↓ TRIG_IN
    ┌───────────────┐
    │   u_ila_2     │  第3个8192 samples
    │  (所有探针)   │
    └───────────────┘
```

**关键**：所有ILA的探针列表完全相同，只是采样时间窗口不同。

## 探针配置

### 当前实现：
- **所有ILA**：连接相同的debug信号（如`DebugTag_*_DebugTag`）
- **触发探针**：FLAG标记的信号配置为`DATA_AND_TRIGGER`
- **数据探针**：其他信号配置为`DATA`

### 示例（100个探针，2个ILA）：
```
u_ila_0: 100个探针（包含1个触发探针）
u_ila_1: 100个探针（相同）
总采样深度: 16384个连续时钟周期
```

## 构建日志检查

成功配置后，日志会显示：

```
INFO: Creating 2 cascaded ILA core(s)...
INFO: ILA u_ila_0 configured with cascade (TRIGIN/TRIGOUT enabled)
INFO: ILA u_ila_1 is the final stage (no cascade output)
INFO: Connected cascade: u_ila_0/TRIG_OUT -> u_ila_1/TRIG_IN
INFO: Connected clock to u_ila_0
INFO: Connected clock to u_ila_1
INFO: trigger probe: DebugTag_1FLAG_start_FLAG1_DebugTag (width=1) on all 2 ILA(s)
INFO: created 100 probes × 2 ILA(s); triggers: 1; data-only: 99
INFO: insert_ila.tcl END - Total sampling depth: 16384 samples (continuous)
```

## 资源消耗

### 单个ILA资源（估算）：
- BRAM: ~8-12 blocks (取决于探针数量和位宽)
- LUTs: ~2000-5000
- FFs: ~1000-2000

### 级联资源倍增：
- **ILA_CASCADE_NUM=2**: 资源 × 2
- **ILA_CASCADE_NUM=3**: 资源 × 3

**注意**：VC707 FPGA资源有限，3个ILA可能接近资源上限。

## 数据读取

### run-ila.tcl会自动处理：
```tcl
# 自动读取所有ILA数据
for {set i 0} {$i < $ila_cascade_num} {incr i} {
    set ila [get_hw_ilas -of_objects [get_hw_devices] -filter "NAME =~ *u_ila_$i*"]
    set data [upload_hw_ila_data $ila]
    # 合并到VCD文件
}
```

### VCD文件格式：
```
时间0-8191:   ILA0数据
时间8192-16383: ILA1数据  ← 连续无间隙
时间16384-24575: ILA2数据
```

## 错误处理

### 配置值超出范围

```
ERROR: ILA_CASCADE_NUM must be between 1 and 3 (got: 5)
```

**解决方案**：设置ILA_CASCADE_NUM为1-3之间的整数

### 资源不足

```
ERROR: [Place 30-494] The design is too large for the device and package.
```

**解决方案**：
1. 减少ILA_CASCADE_NUM
2. 减少C_DATA_DEPTH（修改insert-ila.tcl第23行为4096）
3. 减少debug探针数量（使用更少的markSig标记）

### 级联连接失败

```
ERROR: [Vivado 12-508] cannot connect TRIG_IN to TRIG_OUT
```

**原因**：可能是ILA未正确配置TRIGIN_EN/TRIGOUT_EN属性

## 高级配置

### 修改单个ILA深度

编辑 `board/insert-ila.tcl` 第23行：

```tcl
set_property C_DATA_DEPTH 16384  [get_debug_cores $ila_name]  # 默认8192
```

**注意**：深度必须是2的幂次（1024, 2048, 4096, 8192, 16384...）

### 调整触发位置

默认触发位置在ILA buffer的中间（50%）。如果需要观察触发后更多数据，可在run-ila.tcl中设置：

```tcl
set_property CONTROL.TRIGGER_POSITION 1024 $ila  # 触发后采样1024个sample
```

## 调试技巧

### 验证级联连接：
```tcl
# 在Vivado TCL Console执行
get_debug_ports */TRIG_OUT
get_debug_ports */TRIG_IN
# 应该看到正确的连接关系
```

### 检查探针映射：
```bash
# 查看ltx文件确认所有ILA都有相同探针
cat workspace/rocket64b1_partition_debug/vc707/debug_nets.ltx
```

## 注意事项

1. **资源消耗成倍增加**：每增加一个ILA，BRAM和LUT使用量约增加100%
2. **时序影响**：多个ILA可能影响关键路径时序，建议在timing closure后添加
3. **调试时间**：采样深度增加会延长ILA数据上传时间（16K samples约需10-30秒）
4. **配置一致性**：重新综合时必须使用相同的ILA_CASCADE_NUM，否则ltx文件不匹配
5. **数据合并**：需要在分析工具中手动合并多个ILA的时间轴（Vivado会自动处理）

## 常见问题

### Q: 为什么不直接用一个更大的ILA？
A: Vivado ILA最大深度有限制，且大深度ILA占用更多连续BRAM资源。级联可以使用分散的BRAM。

### Q: 级联会有采样间隙吗？
A: 不会！TRIG_OUT/TRIG_IN连接保证时间连续，无采样间隙。

### Q: 可以只读取部分ILA数据吗？
A: 可以，在run-ila.tcl中选择性读取特定ILA的数据。

## 相关文件

- `board/insert-ila.tcl` - ILA创建和级联配置脚本（**修改后**）
- `board/run-ila.tcl` - ILA触发和数据采集脚本
- `Makefile` - 构建配置（第12行ILA_CASCADE_NUM参数）
