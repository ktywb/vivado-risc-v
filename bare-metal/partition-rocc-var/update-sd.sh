#!/bin/bash
# 快速更新 SD 卡上的 boot.elf

set -e

if [ ! -f boot.elf ]; then
    echo "Error: boot.elf not found. Run 'make' first."
    exit 1
fi

# 查找 USB SD 卡设备
SD_DEVICE=""
for device in /dev/disk/by-path/*-usb-*; do
    if [[ $device != *-part* ]]; then
        SD_DEVICE=$(realpath $device)
        break
    fi
done

if [ -z "$SD_DEVICE" ]; then
    echo "Error: No USB SD card found"
    echo "Please insert SD card and try again"
    exit 1
fi

SD_PART="${SD_DEVICE}1"

echo "Found SD card: $SD_DEVICE"
sudo fdisk -l $SD_DEVICE | head -5

read -r -p "Update boot.elf on this device? [y/N] " response
case "$response" in
    [yY][eE][sS]|[yY])
        echo "Mounting SD card..."
        sudo mkdir -p /mnt/sdcard
        sudo umount /mnt/sdcard 2>/dev/null || true
        sudo mount $SD_PART /mnt/sdcard
        
        # 备份旧文件
        if [ -f /mnt/sdcard/boot.elf ]; then
            echo "Backing up old boot.elf..."
            sudo cp /mnt/sdcard/boot.elf /mnt/sdcard/boot.elf.backup.$(date +%Y%m%d_%H%M%S)
        fi
        
        # 复制新文件
        echo "Copying new boot.elf..."
        sudo cp boot.elf /mnt/sdcard/
        ls -lh /mnt/sdcard/boot.elf
        
        # 同步并卸载
        echo "Syncing..."
        sudo sync
        sudo umount /mnt/sdcard
        
        echo ""
        echo "✓ Done! SD card updated successfully"
        echo "  You can now remove the SD card and insert it into the FPGA board"
        ;;
    *)
        echo "Cancelled"
        exit 0
        ;;
esac
