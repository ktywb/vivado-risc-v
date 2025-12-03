#!/usr/bin/env bash


# start_time=$(date +%s)
# ./runpa
# end_time=$(date +%s)
# elapsed=$((end_time - start_time))
# hours=$((elapsed / 3600))
# minutes=$(((elapsed % 3600) / 60))
# echo "执行时间: ${hours}H${minutes}M"


# /home/name/tools/meow_push/meow_push.sh le VivadoRiscV Runned
# sbt clean


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
./runpa
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
