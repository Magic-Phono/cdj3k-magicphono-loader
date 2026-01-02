#!/bin/bash
set -xeuTo pipefail

# Firmware file name
FW_FILENAME=CDJ3KvLOADER001.UPD

# Uncomment below to enable SSHd in firmware update environment
#START_SSH_SERVER=1

function clear_framebuffer() {
    fb_width=`fbset | grep geometry | cut -f2 -d' '`
    fb_height=`fbset | grep geometry | cut -f3 -d' '`
    echo 1 > /sys/class/vtconsole/vtcon1/bind
    dd if=/dev/zero of=/dev/fb0 bs=$(( ${fb_width} * 2 )) count=$(( ${fb_height} * 2 ))
}

function safe_cp() {
    SRC=$1
    DST=$2

    mkdir -p "$(dirname "$DST")"
    cp "$SRC" "$DST"
}

function copy_pdj_payload() {
    OVERLAY_MEDIA=$1

    OVERLAY_MEDIA_MOUNTPOINT=$(mktemp -d)
    ls "$OVERLAY_MEDIA_MOUNTPOINT"
    mount -o rw "$OVERLAY_MEDIA" "$OVERLAY_MEDIA_MOUNTPOINT"

    PDJ_TAR_WORKDIR=$(mktemp -d)

    # extract payload package
    tar -zxvf $"$ISO_MOUNTPOINT"/pdj.tar.gz  -C "$PDJ_TAR_WORKDIR"

    # add ssh keys from usb to payload package
    if test -f $"$UPDATE_MEDIA_MOUNTPOINT"/authorized_keys; then
       safe_cp $"$UPDATE_MEDIA_MOUNTPOINT"/authorized_keys $"$PDJ_TAR_WORKDIR"/.ssh/authorized_keys
    fi
    tar -cvzf $"$OVERLAY_MEDIA_MOUNTPOINT"/pdj.tar.gz -C "$PDJ_TAR_WORKDIR" .

    # install ssh key for current session
    if ! [ -z "$START_SSH_SERVER" ]; then
        safe_cp $"$UPDATE_MEDIA_MOUNTPOINT"/authorized_keys /home/root/.ssh/authorized_keys
    fi

    umount "$OVERLAY_MEDIA_MOUNTPOINT"
}

# Setup

clear_framebuffer

openvt -s -- echo 'Installing...'

# Start networking

ifup eth0

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

echo 0 > /sys/class/vtconsole/vtcon1/bind

# Copy payload

if [[ -b /dev/mmcblk0p5 ]]; then
    # Renesas model
    copy_pdj_payload /dev/mmcblk0p5
    gui_image D007 "$LANGUAGE" "" >/dev/null 2>&1
elif [[ -b /dev/mmcblk1p8 ]]; then
    # Rockchip model
    copy_pdj_payload /dev/mmcblk1p8
    pkill gui_image
    gui_image D007 "$LANGUAGE" >/dev/null 2>&1 &
else
    echo "Unknown MMC partition layout"
    exit 1
fi

# Start SSH server if required

function cleanup() {
    kill $!
    exit 0
}

if ! [ -z "$START_SSH_SERVER" ]; then
    systemctl start sshd.socket

    trap cleanup SIGINT SIGTERM
    sleep 60d & wait $!
fi

while true
do
	./poweroff
	sleep 1
done

exit 0
