# WriteCombREF 模块架构文档

## 1. 模块概述

`WriteCombREF` 是一个**写合并（Write Combiner）**模块，用于将多个小的数据元组（tuples）合并成更大的数据块后输出。该模块采用**3级流水线架构**，支持高吞吐量的数据处理。

### 主要功能
- 将可变长度的小 tuple 合并成固定大小（64B）的输出块
- 使用哈希分区管理多个独立的合并缓冲区
- 支持初始化、工作和排空三种运行状态
- 实现数据冒险检测和转发机制

---

## 2. 接口定义

```scala
class WriteCombIO(val params: VariablePartitionParameters) extends Bundle {
  val in            : Decoupled[TupleWithHashBundle]  // 输入接口
  val out           : Decoupled[DataWithHashBundle]   // 输出接口
  val partition_num : UInt                            // 分区数量
  val state         : VPState                         // 状态控制
  val busy          : Bool                            // 忙碌标志
  val init_done     : Bool                            // 初始化完成
  val drain_done    : Bool                            // 排空完成
}
```

### 输入信号
- `in.bits.hash`: Tuple 的哈希值（用作 BRAM 地址）
- `in.bits.tuple`: Tuple 数据（可变长度）
- `in.bits.info`: Tuple 元信息（包含长度等）

### 输出信号
- `out.bits.hash`: 输出数据块的哈希值
- `out.bits.data`: 合并后的数据（64B）
- `out.bits.num`: 合并的 tuple 数量
- `out.bits.infos`: 每个 tuple 的元信息数组
- `out.bits.validbytes`: 有效字节数

---

## 3. 存储结构（BRAM）

模块使用 4 类 BRAM 存储器，每类以 hash 值为索引：

| BRAM 名称 | 数据类型 | 功能描述 |
|-----------|---------|---------|
| `numBRAM[hash]` | UInt(BatchCountWidth) | 存储当前缓冲区中已合并的 tuple 数量 |
| `fillRateBRAM[hash]` | UInt(OutputCountWidth) | 存储当前累积的字节数（0-64） |
| `dataBRAM[hash]` | UInt(OutputWidth) | 存储累积的数据缓冲区（512 bits = 64B） |
| `infoBRAMS[i][hash]` | InfoBundle | 存储每个 tuple 的元信息数组（最多 Batchs 个） |

```
地址空间: 0 ~ (2^HashWidth - 1)
示例: HashWidth=10 → 1024 个独立的合并缓冲区
```

---

## 4. 状态机

```
┌─────────┐
│  sInit  │  初始化状态：清空所有 BRAM
│ sBuild  │
└────┬────┘
     │
     ▼
┌─────────┐
│  sPre   │  预备状态
│  sWork  │  工作状态：接收并合并 tuples
└────┬────┘
     │
     ▼
┌─────────┐
│ sDrain  │  排空状态：输出所有未满的缓冲区
└─────────┘
```

### 状态转换说明
1. **sInit/sBuild**: 遍历所有 partition，将 BRAM 初始化为 0
2. **sWork**: 接收输入 tuples，按 hash 值合并到对应缓冲区
3. **sDrain**: 遍历所有 partition，输出所有非空缓冲区

---

## 5. 流水线架构

```
═══════════════════════════════════════════════════════════════════════════
                           3-Stage Pipeline
═══════════════════════════════════════════════════════════════════════════

    Stage 1              Stage 2                   Stage 3
┌─────────────┐      ┌─────────────┐          ┌─────────────┐
│   Input &   │      │ Calculate & │          │  Output &   │
│  BRAM Read  │ ───> │ BRAM Update │ ──────> │ BRAM Write  │
│   (num/     │      │ (num/fill)  │          │ (data/info) │
│  fillRate)  │      │             │          │             │
└─────────────┘      └─────────────┘          └─────────────┘
      │                    │                        │
   s1_valid             s2_valid                 s3_valid
   s1_ready             s2_ready                 s3_ready
   s1_fires             s2_fires                 s3_fires
```

### 流水线控制信号
```scala
s3_ready = io.out.ready                // S3 准备好当输出被接受
s2_ready = s3_ready || !s2_valid       // S2 准备好当 S3 空闲或无效
s1_ready = s2_ready || !s1_valid       // S1 准备好当 S2 空闲或无效

s1_fires = io.in.fire                  // S1 触发：输入握手成功
s2_fires = s1_valid && s2_ready        // S2 触发：S1 有效且 S2 准备好
s3_fires = s2_valid && s3_ready        // S3 触发：S2 有效且 S3 准备好
```

---

## 6. Pipeline Stage 1 (S1)

### 功能：输入捕获 & BRAM 读取

```
输入数据流:
┌──────────────────┐
│ io.in.bits.hash  │ ─┐
│ io.in.bits.tuple │  │
│ io.in.bits.info  │  │
└──────────────────┘  │
                      ├──> s1_bramAddr
┌──────────────────┐  │    (Mux: drain ? drainCounter : hash)
│  drainCounter    │ ─┘
└──────────────────┘

BRAM 读取操作:
┌────────────────────────────────────────┐
│ s1_numRead = numBRAM.read(s1_bramAddr) │
│ s1_fillRateRead = fillRateBRAM.read()  │
└────────────────────────────────────────┘
```

### 主要操作
1. **地址选择**：
   - 工作模式：使用输入的 `hash` 值
   - 排空模式：使用 `drainCounter` 顺序遍历

2. **BRAM 读取**（同步读，1周期延迟）：
   - 读取 `numBRAM[hash]` → 当前已合并的 tuple 数量
   - 读取 `fillRateBRAM[hash]` → 当前累积的字节数

3. **数据缓存**：
   ```scala
   s1_hash  = RegEnable(hash_value, s1_bramEnable)
   s1_tuple = RegEnable(io.in.bits.tuple, io.in.fire)
   s1_info  = RegEnable(io.in.bits.info, io.in.fire)
   ```

4. **Pipeline Cache**（处理反压）：
   ```scala
   s1_num = PipelineUtils.cache(s1_numRead, 
                                 hold = s1_bramEnableNext && !s2_ready,
                                 clear = s2_ready)
   ```

### 输出到 S2
- `s1_hash`, `s1_tuple`, `s1_info`
- `s1_num`, `s1_fillRate`
- `s1_valid`

---

## 7. Pipeline Stage 2 (S2)

### 功能：计算逻辑 & BRAM 更新

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Hazard 检测与转发                                 │
├─────────────────────────────────────────────────────────────────────────┤
│  检测场景: 连续两次访问相同 hash                                         │
│                                                                          │
│  s2_hazardV = !drain && s2_fires && s2_firesNext                        │
│               && (s2_hazardHash == s1_hash)                             │
│                                                                          │
│  转发逻辑:                                                               │
│    s2_numWire      = s2_hazardV ? s2_hazardNum      : s1_num            │
│    s2_fillRateWire = s2_hazardV ? s2_hazardFillRate : s1_fillRate       │
│                                                                          │
│  目的: 避免 BRAM 写后读冲突，确保数据一致性                              │
└─────────────────────────────────────────────────────────────────────────┘
```

### 填充状态检测

```
s2_step = s1_info.tuple_len  (当前 tuple 的长度，单位：字节)
FILLFULL = 64                 (输出块大小，单位：字节)

四种情况判断:
┌──────────────┬─────────────────────────┬─────────────────────┐
│   条件标志   │         判断逻辑         │      含义说明        │
├──────────────┼─────────────────────────┼─────────────────────┤
│  stepGq      │  step ≥ FILLFULL        │ Tuple 本身 ≥ 64B    │
│              │                         │ (大 Tuple 直通)     │
├──────────────┼─────────────────────────┼─────────────────────┤
│  isGt        │  fillRate + step > 64   │ 会溢出              │
│              │                         │ (输出旧数据)        │
├──────────────┼─────────────────────────┼─────────────────────┤
│  isEq        │  fillRate + step = 64   │ 正好填满            │
│              │                         │ (合并后输出)        │
├──────────────┼─────────────────────────┼─────────────────────┤
│  isLt        │  fillRate + step < 64   │ 还有空间            │
│              │                         │ (继续累积)          │
└──────────────┴─────────────────────────┴─────────────────────┘
```

### 状态更新逻辑

```
┌────────────┬──────────────────┬──────────────────────┬─────────────┐
│   情况     │   numNext        │   fillRateNext       │   动作      │
├────────────┼──────────────────┼──────────────────────┼─────────────┤
│  stepGq    │  numWire (保持)  │  fillRateWire (保持) │ 不更新      │
├────────────┼──────────────────┼──────────────────────┼─────────────┤
│  isGt      │  1               │  step                │ 重置为新值  │
├────────────┼──────────────────┼──────────────────────┼─────────────┤
│  isEq      │  0               │  0                   │ 清空        │
├────────────┼──────────────────┼──────────────────────┼─────────────┤
│  isLt      │  numWire + 1     │  fillRateWire + step │ 累加        │
└────────────┴──────────────────┴──────────────────────┴─────────────┘
```

### BRAM 写入操作

1. **写入 numBRAM**:
   ```scala
   when(init || (s2_fires && ((inReadyState && !s2_stepGqWire) || 
                               (drain && s2_numWire > 0)))) {
     numBRAM.write(address, s2_numNext)
   }
   ```

2. **写入 fillRateBRAM**:
   ```scala
   when(init || (s2_fires && ((inReadyState && !s2_stepGqWire) || 
                               (drain && s2_fillRateWire > 0)))) {
     fillRateBRAM.write(address, s2_fillRateNext)
   }
   ```

### BRAM 读取操作

```scala
s2_dataRead = dataBRAM.read(s1_hash, s2_fires)
s2_infosRead(i) = infoBRAMS(i).read(s1_hash, s2_fires)
```

### 输出计算

```
s2_numOutput = Drain 模式 ? s2_numWire
             : stepGq     ? 1
             : isGt       ? s2_numWire
             : isEq       ? s2_numWire + 1
             : 0

s2_validbytes = Drain 模式 ? s2_fillRateWire
              : stepGq     ? s2_step
              : isGt       ? s2_fillRateWire
              : isEq       ? s2_fillRateWire + s2_step
              : 0
```

### 输出到 S3
- `s2_hash`, `s2_tuple`, `s2_info`
- `s2_data`, `s2_infos`
- `s2_numOriginal`, `s2_numOutput`
- `s2_fillRate`, `s2_validbytes`
- `s2_stepGq`, `s2_isGt`, `s2_isEq`, `s2_isLt`

---

## 8. Pipeline Stage 3 (S3)

### 功能：输出生成 & BRAM 写入

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Hazard 检测与转发                                 │
├─────────────────────────────────────────────────────────────────────────┤
│  检测场景: 连续写入同一 hash 的 data/info                                │
│                                                                          │
│  s3_hazardWrite = RegNext(!s2_stepGq && (s2_isGt || s2_isLt))          │
│  s3_hazardV = !drain && s3_fires && s3_firesNext                        │
│               && (s3_hazardHash == s2_hash) && s3_hazardWrite           │
│                                                                          │
│  转发逻辑:                                                               │
│    s3_dataWire = s3_hazardV ? s3_hazardData : s2_data                   │
│    s3_infoWire = s3_hazardV ? s3_hazardInfo : s2_infos                  │
│                                                                          │
│  目的: 避免 data/info BRAM 的写后读冲突                                 │
└─────────────────────────────────────────────────────────────────────────┘
```

### 数据合并操作

```
数据拼接公式:
┌───────────────────────────────────────────────────────────────┐
│  s3_dataCat = (s2_tuple << (s2_fillRate * 8)) | s3_dataWire   │
└───────────────────────────────────────────────────────────────┘

示例: fillRate = 8 bytes, tuple = 0x1234 (2 bytes)
      
      现有数据:  [0x00][0x00]...[0xAA][0xBB][0xCC][0xDD]...
                                  ↑
                                位置 0

      新 tuple:  0x1234 << (8*8) 左移到字节 8 的位置
      
      结果:      [0x12][0x34]...[0xAA][0xBB][0xCC][0xDD]...
```

### 输出数据选择

```
┌────────────┬──────────────────────────────────────────┐
│   条件     │  s3_dataOutput (输出数据)                 │
├────────────┼──────────────────────────────────────────┤
│  drain     │  s2_data                                 │
│            │  (直接输出缓存的数据)                     │
├────────────┼──────────────────────────────────────────┤
│  stepGq    │  s2_tuple                                │
│            │  (大 tuple 直接输出)                     │
├────────────┼──────────────────────────────────────────┤
│  isGt      │  s2_data                                 │
│            │  (输出旧的累积数据)                       │
├────────────┼──────────────────────────────────────────┤
│  isEq      │  s3_dataCat                              │
│            │  (输出合并后的完整数据)                   │
├────────────┼──────────────────────────────────────────┤
│  isLt      │  0 (不输出)                              │
└────────────┴──────────────────────────────────────────┘
```

### Info 输出选择

```
┌────────────┬──────────────────────────────────────────┐
│   条件     │  s3_infoOutput (元信息数组)               │
├────────────┼──────────────────────────────────────────┤
│  drain     │  s2_infos                                │
│            │  (直接输出缓存的 infos)                   │
├────────────┼──────────────────────────────────────────┤
│  stepGq    │  [s2_info, 0, 0, ...]                    │
│            │  (只有一个大 tuple)                       │
├────────────┼──────────────────────────────────────────┤
│  isGt      │  s2_infos                                │
│            │  (输出旧的 infos)                         │
├────────────┼──────────────────────────────────────────┤
│  isEq      │  s2_infos with s2_info appended          │
│            │  (旧 infos + 新 info)                     │
├────────────┼──────────────────────────────────────────┤
│  isLt      │  0 (不输出)                              │
└────────────┴──────────────────────────────────────────┘
```

### BRAM 写入逻辑

#### Data BRAM 写入
```scala
s3_dataWriteData = init || drain ? 0
                 : isGt          ? s2_tuple  (新 tuple 作为下一轮开始)
                 : isLt          ? s3_dataCat (合并后的数据)
                 : 0

when(init || (s2_valid && s3_ready && !s2_stepGq)) {
  dataBRAM.write(address, s3_dataWriteData)
}
```

#### Info BRAM 写入
```scala
for (i <- 0 until Batchs) {
  写入条件: init || s3_infoWriteEnable(i)
  
  isGt/stepGq: infoBRAMS(0).write(hash, s2_info)  // 新 tuple 放位置 0
  isLt:        infoBRAMS(num).write(hash, s2_info) // 追加到末尾
}
```

### 输出有效标志

```scala
s3_valid = (drain && s2_fillRate > 0) ||  // Drain 模式：有数据就输出
           (s2_stepGq || s2_isGt || s2_isEq)  // Work 模式：这三种情况输出
```

### 输出到接口

```
io.out.valid       ← s3_valid
io.out.bits.hash   ← s3_hash
io.out.bits.data   ← s3_data      (64B 数据块)
io.out.bits.num    ← s3_num       (包含的 tuple 数量)
io.out.bits.infos  ← s3_infos     (每个 tuple 的元信息)
io.out.validbytes  ← s3_validbytes (有效字节数: 1-64)
```

---

## 9. 数据流动示例

### 示例 1: 小 Tuple 累积（isLt）

```
初始状态: hash=5, num=0, fillRate=0, data=0x00...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Cycle 1: 输入 tuple1 (8B)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

S1: 读取 numBRAM[5]=0, fillRateBRAM[5]=0
    缓存 hash=5, tuple=tuple1, info1

S2: 计算 fillRate=0, step=8
    判断: isLt (0+8 < 64) ✓
    更新: numNext=1, fillRateNext=8
    写入 numBRAM[5]←1, fillRateBRAM[5]←8

S3: 写入 dataBRAM[5] ← tuple1
    写入 infoBRAMS(0)[5] ← info1
    输出: 无 (s3_valid=false)

结果: num=1, fillRate=8, data=[tuple1][  空  ]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Cycle 2: 输入 tuple2 (12B)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

S1: 读取 numBRAM[5]=1, fillRateBRAM[5]=8
    缓存 hash=5, tuple=tuple2, info2

S2: 计算 fillRate=8, step=12
    判断: isLt (8+12 < 64) ✓
    更新: numNext=2, fillRateNext=20
    读取 dataBRAM[5] → old_data

S3: 合并数据: dataCat = (tuple2 << 64) | old_data
    写入 dataBRAM[5] ← dataCat
    写入 infoBRAMS(1)[5] ← info2
    输出: 无 (s3_valid=false)

结果: num=2, fillRate=20, data=[tuple1][tuple2][  空  ]
```

### 示例 2: 填满输出（isEq）

```
当前状态: hash=5, num=2, fillRate=20, data=[tuple1][tuple2][  ]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
输入 tuple3 (44B)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

S1: 读取 numBRAM[5]=2, fillRateBRAM[5]=20

S2: 计算 fillRate=20, step=44
    判断: isEq (20+44 = 64) ✓
    更新: numNext=0, fillRateNext=0
    读取 dataBRAM[5]

S3: 合并数据: dataCat = (tuple3 << 160) | old_data
    写入 dataBRAM[5] ← 0 (清空)
    写入 infoBRAMS ← 0 (清空)
    
    输出: ✓
      hash = 5
      data = [tuple1][tuple2][tuple3] (完整 64B)
      num = 3
      infos = [info1, info2, info3]
      validbytes = 64

结果: num=0, fillRate=0, data清空
```

### 示例 3: 溢出处理（isGt）

```
当前状态: hash=5, num=2, fillRate=20, data=[tuple1][tuple2][  ]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
输入 tuple3 (50B)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

S1: 读取 numBRAM[5]=2, fillRateBRAM[5]=20

S2: 计算 fillRate=20, step=50
    判断: isGt (20+50 > 64) ✓
    更新: numNext=1, fillRateNext=50 (新 tuple 作为下一轮)
    读取 dataBRAM[5]

S3: 写入 dataBRAM[5] ← tuple3 (新 tuple)
    写入 infoBRAMS(0)[5] ← info3
    
    输出: ✓ (输出旧数据)
      hash = 5
      data = [tuple1][tuple2][0x00...] (部分填充)
      num = 2
      infos = [info1, info2]
      validbytes = 20

结果: num=1, fillRate=50, data=[tuple3][  空  ]
```

### 示例 4: 大 Tuple 直通（stepGq）

```
当前状态: hash=7, num=0, fillRate=0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
输入 big_tuple (64B)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

S1: 读取 numBRAM[7]=0, fillRateBRAM[7]=0

S2: 计算 step=64
    判断: stepGq (64 ≥ 64) ✓
    更新: num 和 fillRate 保持不变

S3: 输出: ✓ (直接输出，不写 BRAM)
      hash = 7
      data = big_tuple
      num = 1
      infos = [info]
      validbytes = 64

结果: num=0, fillRate=0 (状态未改变)
```

### 示例 5: Drain 模式

```
状态: sDrain

遍历所有 hash (0 ~ partition_num-1):
  hash=0: fillRate=0  → 跳过
  hash=1: fillRate=15 → 输出部分数据 (15B)
  hash=2: fillRate=48 → 输出部分数据 (48B)
  hash=3: fillRate=0  → 跳过
  ...

每个非空 partition:
  S1: 读取 numBRAM[hash], fillRateBRAM[hash]
  S2: 读取 dataBRAM[hash], infoBRAMS[hash]
      写入 numBRAM[hash]←0, fillRateBRAM[hash]←0
  S3: 输出 data, infos
      写入 dataBRAM[hash]←0, infoBRAMS[hash]←0
```

---

## 10. Hazard 处理机制

### S2 Hazard: num/fillRate 转发

**问题**：连续两个 cycle 访问同一个 hash

```
Cycle N:   hash=5, fillRate=8  → 计算 fillRateNext=20
Cycle N+1: hash=5               → 需要 fillRate=20，但 BRAM 还未写入
```

**解决方案**：数据转发

```scala
s2_hazardV = !drain && s2_fires && s2_firesNext && (s2_hazardHash == s1_hash)

s2_fillRateWire = s2_hazardV ? s2_hazardFillRate  // 转发计算结果
                             : s1_fillRate         // BRAM 读取结果
```

### S3 Hazard: data/info 转发

**问题**：连续两个 cycle 写入并读取同一个 hash 的 data

```
Cycle N:   hash=5, isLt → 写入 dataBRAM[5] ← merged_data
Cycle N+1: hash=5, isLt → 读取 dataBRAM[5] (可能读到旧数据)
```

**解决方案**：数据转发

```scala
s3_hazardV = !drain && s3_fires && s3_firesNext 
             && (s3_hazardHash == s2_hash) && s3_hazardWrite

s3_dataWire = s3_hazardV ? s3_hazardData  // 转发上一次写入的数据
                         : s2_data         // BRAM 读取结果
```

---

## 11. 时序图

```
Cycle:     0    1    2    3    4    5    6    7
         ┌────┬────┬────┬────┬────┬────┬────┬────┐
io.in    │ T1 │ T2 │ T3 │ T4 │ -- │ T5 │ T6 │ -- │
         └────┴────┴────┴────┴────┴────┴────┴────┘

         ┌────┬────┬────┬────┬────┬────┬────┬────┐
S1       │ T1 │ T2 │ T3 │ T4 │ -- │ T5 │ T6 │ -- │
         └────┴────┴────┴────┴────┴────┴────┴────┘
                   ↓ 读 num/fillRate

         ┌────┬────┬────┬────┬────┬────┬────┬────┐
S2       │ -- │ T1 │ T2 │ T3 │ T4 │ -- │ T5 │ T6 │
         └────┴────┴────┴────┴────┴────┴────┴────┘
                   ↓ 计算 & 写 num/fillRate & 读 data/info

         ┌────┬────┬────┬────┬────┬────┬────┬────┐
S3       │ -- │ -- │ T1 │ T2 │ T3*│ T4 │ -- │ T5 │
         └────┴────┴────┴────┴────┴────┴────┴────┘
                        ↓ 写 data/info & 输出

         ┌────┬────┬────┬────┬────┬────┬────┬────┐
io.out   │ -- │ -- │ -- │ -- │ T3*│ -- │ -- │ -- │
         └────┴────┴────┴────┴────┴────┴────┴────┘

T3*: T3 触发 isEq，输出合并后的数据块
```

---

## 12. 性能特性

### 吞吐量
- **理论峰值**: 每周期 1 个 tuple（流水线满载）
- **实际吞吐**: 取决于输入速率和输出反压
- **延迟**: 3 个周期（流水线深度）

### 资源利用
```
BRAM 资源:
  - numBRAM:      1 × (2^HashWidth) × BatchCountWidth bits
  - fillRateBRAM: 1 × (2^HashWidth) × OutputCountWidth bits
  - dataBRAM:     1 × (2^HashWidth) × OutputWidth bits
  - infoBRAMS:    Batchs × (2^HashWidth) × InfoBundle bits

寄存器资源:
  - Pipeline 寄存器: ~3 × (hash + tuple + info + metadata)
  - 控制逻辑: ~100 FFs

组合逻辑:
  - Hazard 检测: 比较器 × 2
  - 填充判断: 加法器 + 比较器 × 4
  - 数据合并: 移位器 + OR 门
```

### 优化特性
1. **Hazard 转发**: 避免流水线停顿
2. **Pipeline Cache**: 处理反压时保持数据
3. **并行 BRAM 访问**: S2 同时读写不同 BRAM
4. **Early Valid**: S3 在 fires 时立即设置 valid

---

## 13. 使用建议

### 参数配置
```scala
HashWidth = 10        // 1024 个独立缓冲区
OutputBytes = 64      // 输出块大小
Batchs = 8            // 最多合并 8 个 tuples
```

### 性能调优
1. **增大 HashWidth**: 减少 hash 冲突，提高并行度
2. **调整 Batchs**: 匹配实际平均合并数量
3. **优化输出接口**: 确保下游能及时消费数据

### 常见问题
1. **Q**: 为什么需要 Drain 模式？  
   **A**: 确保所有未满的缓冲区都能输出，避免数据丢失

2. **Q**: stepGq 情况为什么不更新 BRAM？  
   **A**: 大 tuple 直接输出，不需要缓存

3. **Q**: Hazard 转发会影响时序吗？  
   **A**: 转发路径经过寄存器，时序开销可控

---

## 14. 总结

`WriteCombREF` 模块通过以下设计实现高效的写合并：

✅ **3级流水线架构**: 实现高吞吐量  
✅ **多级 Hazard 转发**: 避免数据冲突  
✅ **灵活的合并策略**: 支持 4 种填充情况  
✅ **完整的状态管理**: Init/Work/Drain 三态控制  
✅ **BRAM 优化**: 并行读写，减少访问冲突  

该模块适用于需要将可变长度小数据块合并成固定大小输出块的场景，如数据库 Join 操作、网络数据包合并等。
