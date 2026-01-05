#!/bin/bash

function clear_framebuffer() {
    fb_width=`fbset | grep geometry | cut -f2 -d' '`
    fb_height=`fbset | grep geometry | cut -f3 -d' '`
    dd if=/dev/zero of=/dev/fb0 bs=$(( ${fb_width} * 2 )) count=$(( ${fb_height} * 2 ))
}

function read_version() {
    FWVERSION=`cat VERSION`
}

function sysinfo() {
    TTYNO=5

    echo "======================================" > /dev/tty$TTYNO
    cat /proc/device-tree/model > /dev/tty$TTYNO
    echo "" > /dev/tty$TTYNO
    cat /etc/issue.net > /dev/tty$TTYNO
    dmesg | grep "Boot CPU" > /dev/tty$TTYNO
    dmesg | grep "Memory: " > /dev/tty$TTYNO
    echo "" > /dev/tty$TTYNO
    fw_printenv  | grep "ver=" > /dev/tty$TTYNO
    uname -a > /dev/tty$TTYNO
    echo "" > /dev/tty$TTYNO
    fw_printenv  | grep "dtb=" > /dev/tty$TTYNO
    fw_printenv  | grep "release" > /dev/tty$TTYNO
    fw_printenv  | grep "rev_" > /dev/tty$TTYNO
    fw_printenv  | grep "bootcmd_sd=" > /dev/tty$TTYNO
    fw_printenv  | grep "bootcmd=" > /dev/tty$TTYNO
    echo "" > /dev/tty$TTYNO
    lsblk -a > /dev/tty$TTYNO
}

# Setup

clear_framebuffer
read_version

echo 1 > /sys/class/vtconsole/vtcon1/bind
openvt -c 5 -s -- echo "Magic Phono SYSINFO Firmware v$FWVERSION"
chvt 5

# Dump sysinfo to screen

sysinfo

# Cleanup

echo 0 > /sys/class/vtconsole/vtcon1/bind

exit 0
