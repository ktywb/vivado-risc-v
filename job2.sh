#!/usr/bin/env bash

set -euo pipefail

FLAG_NAME=VIVADORV_RUNNING
LOCKFILE="/var/tmp/vivadorv.running.lock"

# 1) 先看环境变量（会话级）
if [[ "${VIVADORV_RUNNING:-0}" == "1" ]]; then
  echo "警告: 检测到 ${FLAG_NAME}=1，本次不运行。"
  exit 2
fi

# 2) 系统级互斥锁（避免并发）
exec 9>"$LOCKFILE"
if ! flock -n 9; then
  echo "警告: 另一个实例正在运行（锁: $LOCKFILE）。退出。"
  exit 3
fi

# 3) 子进程也能看到的会话标志
export VIVADORV_RUNNING=1

# 4) 退出时清理锁
cleanup() {
  flock -u 9
  rm -f "$LOCKFILE"
}
trap cleanup EXIT

# 5) 计时 & 运行
SECONDS=0
set +e

# Configuration combinations
declare -a CONFIGS=(
  "64:32"
  "256:128"
  "128:64"
  "256:64"
)

gen_parameter_scala_file(){
local tuple_width=${1:-64}
local key_width=${2:-32}

cat > /home/name/vivado_prj/vivado-risc-v/generators/partition-chisel/src/main/scala/fixed-partition/Parameters.scala << GENPARAMETERSCALAFILE1
// See README.md for license details.

package partition.fixed

import chisel3._
import chisel3.util._

case class FixedPartitionParameters(
    debugEnable: Boolean = false,
    assertEnable: Boolean = false,
    keepEnable: Boolean = false,
    InputWidth: Int = 256,
    TupleWidth: Int = ${tuple_width},
    KeyWidth: Int = ${key_width},
    HashWidth: Int = 10,
    FIFODepth: Seq[Int] = Seq(16, 16, 16),
    OutputWidth: Int = 256
) {
GENPARAMETERSCALAFILE1

cat >> /home/name/vivado_prj/vivado-risc-v/generators/partition-chisel/src/main/scala/fixed-partition/Parameters.scala << 'GENPARAMETERSCALAFILE2'
  println(s"FixedPartitionParameters: TupleWidth = $TupleWidth, KeyWidth = $KeyWidth")
  // Ensure that the parameters are valid
  if (assertEnable) {
    assert(
      InputWidth >= TupleWidth,
      "InputWidth must be greater than or equal to TupleWidth"
    )
    assert(
      KeyWidth <= TupleWidth,
      "KeyWidth must be less than or equal to TupleWidth"
    )
    assert(
      InputWidth % TupleWidth == 0,
      "InputWidth must be a multiple of TupleWidth"
    )
  }

  def parallelism: Int = InputWidth / TupleWidth
  def parallelismW: Int = log2Ceil(parallelism + 1)
  def tupleWidthBytes: Int = TupleWidth / 8

  def generateCppHeader(filename: String = "config-gen.h"): Unit = {
    val content = s"""
#ifndef CONFIGGEN_H
#define CONFIGGEN_H

// Auto-generated from FixedPartitionParameters
#define DEBUG_ENABLE ${if (debugEnable) 1 else 0}
#define ASSERT_ENABLE ${if (assertEnable) 1 else 0}
#define INPUT_WIDTH $InputWidth
#define TUPLE_WIDTH $TupleWidth
#define KEY_WIDTH $KeyWidth
#define HASH_WIDTH $HashWidth
#define OUTPUT_WIDTH $OutputWidth
#define PARALLELISM $parallelism

// FIFO Depths
#define FIFO_DEPTH_0 ${FIFODepth(0)}
#define FIFO_DEPTH_1 ${FIFODepth(1)}
#define FIFO_DEPTH_2 ${FIFODepth(2)}

// Derived parameters
#define MAX_PARTITIONS (1 << HASH_WIDTH)
#define TUPLE_MASK ((1ULL << TUPLE_WIDTH) - 1)
#define HASH_MASK ((1ULL << HASH_WIDTH) - 1)

#endif // CONFIG_H
"""

    import java.io.PrintWriter
    import java.io.File

    val file = new File(s"src/main/resources/FixedPartition/csrc/$filename")
    file.getParentFile.mkdirs()
    val writer = new PrintWriter(file)
    writer.write(content)
    writer.close()
    println(s"Generated C++ header: ${file.getAbsolutePath}")
  }
}
GENPARAMETERSCALAFILE2
}
ITER=1
# Loop through all configurations
for config in "${CONFIGS[@]}"; do
  IFS=':' read -r TUPLE_WIDTH KEY_WIDTH <<< "$config"
  echo "================================================================"
  echo " START ITER ${ITER} "
  echo "================================================================\n"
  echo "Generating configuration: TupleWidth=${TUPLE_WIDTH}, KeyWidth=${KEY_WIDTH} ==="
  gen_parameter_scala_file "$TUPLE_WIDTH" "$KEY_WIDTH"
  echo "Generated: /home/name/Desktop/FixedPartitionParameters.scala"
  echo ""

  ./runpa

  mv /home/name/vivado_prj/vivado-risc-v/workspace/rocket64b1_partition \
     /home/name/vivado_prj/vivado-risc-v/workspace/rocket64b1_partition_Fix_T${TUPLE_WIDTH}_K${KEY_WIDTH}
  
  ITER=$((ITER+1))
  echo " "

done

echo "All configurations completed!"



rc=$?
set -e

# 6) 打印耗时
elapsed=$SECONDS
hours=$((elapsed / 3600))
minutes=$(((elapsed % 3600) / 60))
TIME_TXT="${hours}H${minutes}M"
echo "执行时间: ${TIME_TXT}"

# 7) 后续动作（按你原来的）
/home/name/tools/meow_push/meow_push.sh le VivadoRiscV Runned-${TIME_TXT} || true
sbt clean || true

exit "$rc"
