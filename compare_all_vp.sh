#!/bin/bash

LocalFolder=$HOME/vivado_prj/vivado-risc-v/generators/partition-chisel/src/main/scala
RemoteFolder=$HOME/partition-chipyard/generators/partition-chisel-REMOTE/src/main/scala

# 查找所有 variable-partition 和 variable-partition-* 目录下的文件
files=$(cd "$LocalFolder" && find . -type f -name "*.scala" | grep -E "variable-partition" | sort)
# files=$(cd "$LocalFolder" && find . -type f -name "*.scala" | grep -E "fixed-partition" | sort)

echo "正在打开以下文件的对比视图："
echo "$files"
echo ""

# 逐个打开 diff 比较
for file in $files; do
    local_file="$LocalFolder/$file"
    remote_file="$RemoteFolder/$file"
    
    if [ -f "$local_file" ] && [ -f "$remote_file" ]; then
        echo "比较: $file"
        code --diff "$local_file" "$remote_file"
        sleep 0.2  # 避免打开太快
    elif [ -f "$local_file" ]; then
        echo "仅本地存在: $file"
    else
        echo "仅远程存在: $file"
    fi
done

echo ""
echo "完成!"
