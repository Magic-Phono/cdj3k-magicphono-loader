#!/bin/bash
set -xeuTo pipefail

# Firmware file name
FW_FILENAME=CDJ3KvSDBOOT001.UPD

function clear_framebuffer() {
    fb_width=`fbset | grep geometry | cut -f2 -d' '`
    fb_height=`fbset | grep geometry | cut -f3 -d' '`
    dd if=/dev/zero of=/dev/fb0 bs=$(( ${fb_width} * 2 )) count=$(( ${fb_height} * 2 ))
}

function enable_sd_boot() {
    echo 0 > /sys/block/mmcblk0boot1/force_ro
    fw_setenv bootargs_sd 'rw root=/dev/mmcblk1p1 rootfstype=ext4 rootwait loglevel=7 earlycon console=ttySC0,115200'
    fw_setenv bootcmd 'run bootcmd_sd; run bootcmd_emmc'
    echo 1 > /sys/block/mmcblk0boot1/force_ro
}

# Wait and mount

UPDATE_MEDIA_DEVICE=
UPDATE_MEDIA_MOUNTPOINT=

while read -r MOUNT; do
    DEVICE=$(echo "$MOUNT" | cut -d' ' -f1)
    MOUNTPOINT=$(echo "$MOUNT" | cut -d' ' -f2)
    if [[ -e $MOUNTPOINT/$FW_FILENAME ]]; then
        UPDATE_MEDIA_DEVICE=$DEVICE
        UPDATE_MEDIA_MOUNTPOINT=$MOUNTPOINT
        break
    fi
done < /proc/mounts

if [[ -z $UPDATE_MEDIA_DEVICE ]]; then
    echo "Couldn't locate update media"
    exit 1
fi

mount -o remount,rw "$UPDATE_MEDIA_DEVICE" "$UPDATE_MEDIA_MOUNTPOINT"

SCRIPT_NAME=$(basename "$0")
exec >"$UPDATE_MEDIA_MOUNTPOINT"/"$SCRIPT_NAME".log
exec 2>&1

trap 'printf "[%s] %s: %s\n" "$(cut -d" " -f1 /proc/uptime)" "$SCRIPT_NAME" "${BASH_COMMAND:-}" 1>&2' DEBUG

ISO_MOUNTPOINT=$1
LANGUAGE=$2

# Copy payload

if [[ -b /dev/mmcblk0p5 ]]; then
    # Renesas model
    enable_sd_boot
    gui_image D007 "$LANGUAGE" "" >/dev/null 2>&1
elif [[ -b /dev/mmcblk1p8 ]]; then
    # Rockchip model
    # !! UNSUPPORTED !!
	gui_image D003 "Model unsupported." ${language} >/dev/null 2>&1
	while true; do sleep 1; done;
else
    echo "Unknown MMC partition layout"
    exit 1
fi
