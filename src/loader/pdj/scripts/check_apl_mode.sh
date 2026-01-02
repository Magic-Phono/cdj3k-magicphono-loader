#!/bin/sh

if [[ -c /dev/subucom_spi1.0 ]] ; then
    SUBUCOM_DEVNAME=subucom_spi1.0
fi

if [[ -c /dev/subucom_spi2.0 ]] ; then
    SUBUCOM_DEVNAME=subucom_spi2.0
fi

/bin/echo ${SUBUCOM_DEVNAME}

/home/root/pdj/subucom_read -d /dev/${SUBUCOM_DEVNAME} 64


#######################################################################################

function fix_permissions() {
    echo "Fixing file permissions..."

    chown root:root /home/root
    chown root:root /home/root/.ssh/ || true
    chown root:root /home/root/.ssh/authorized_keys || true
}

function start_ssh() {
    echo "Starting SSH..."

    systemctl start sshd.socket
}

function check_compat() {
    echo "Checking compatibility..."

    RELEASE_MAJOR=$(fw_printenv -n release | awk '{split($0,a,"."); print a[1]}')
    RELEASE_MINOR=$(fw_printenv -n release | awk '{split($0,a,"."); print a[2]}')

    echo "  $RELEASE_MAJOR.$RELEASE_MINOR found."

    if [ "$RELEASE_MAJOR" = "3" ] && [ "$RELEASE_MINOR" = "19" ]; then
        return 1
    fi
    if [ "$RELEASE_MAJOR" = "3" ] && [ "$RELEASE_MINOR" = "20" ]; then
        return 1
    fi

    return 0
}

function check_usb_package() {
    echo "Waiting for USB..."
    
    local USB=

    until [ -n "$USB" ]
    do
        USB=$(cat /proc/mounts | grep usb)
        sleep 1
    done

    echo "Looking for package..."

    DEVICE=$(echo "$USB" | cut -d' ' -f1)
    MOUNTPOINT=$(echo "$USB" | cut -d' ' -f2)

    if ! [ -f "$MOUNTPOINT/CDJ3KPACKAGE.TAR.GZ" ]; then
        echo "Could not find package, exiting and booting normally."

        rm -rf /tmp/testmode
        exit 0
    fi

    PACKAGE="$MOUNTPOINT/CDJ3KPACKAGE.TAR.GZ"
}

function extract_package_to_tmp() {
    echo "Extracting package to /tmp..."

    tar -zxvf $"$MOUNTPOINT/CDJ3KPACKAGE.TAR.GZ" -C /tmp/
}

function stop_cdj() {
    echo "Stopping CDJ..."

    systemctl disable restart-EP122.service
    systemctl disable EP122.service 
    systemctl stop restart-EP122.service 
    systemctl stop EP122.service
}

function uninstall_magic_key_check() {
    rm /mnt/pdj.tar.gz
}

function tweak_environment() {
    /bin/echo -n ee100000.sd > /sys/bus/platform/drivers/sh_mobile_sdhi/unbind 2> /dev/null
    /sbin/sysctl vm.stat_interval=120
    /usr/bin/taskset -p 01 `pgrep kswapd0`
    /sbin/sysctl -w kernel.sched_rt_runtime_us=-1
    /bin/echo never > /sys/kernel/mm/transparent_hugepage/enabled
    /usr/bin/taskset -p 02 `pgrep irq/24-ec700000`
    /bin/ps -e | /bin/grep irq/24-ec700000 | /usr/bin/awk '{print $1}' | /usr/bin/xargs /usr/bin/chrt -f -p 99
    /bin/ps -e | /bin/grep -w ${SUBUCOM_DEVNAME} | /usr/bin/awk '{print $1}' | /usr/bin/xargs /usr/bin/taskset -p 20
    /usr/bin/aplay -D plughw:0,0 /home/root/pdj/silence.wav
    /bin/cat /proc/asound/DACDIT/pcm1p/info | grep dit4192
    if [ $? = 0 ] ; then
        /bin/echo "Update Channel Status."
        /usr/bin/aplay -D plughw:0,1 /home/root/pdj/silence.wav
    fi
}

# Start SSH

if test -f /home/root/.ssh/authorized_keys; then
    fix_permissions
    start_ssh
fi

# # Check compatibility
#
# check_compat
# if [ $? = 0 ] ; then
#     # uninstall_magic_key_check

#     # systemctl disable xserver-nodm
#     # systemctl stop xserver-nodm
#     # echo 1 > /sys/class/vtconsole/vtcon1/bind
#     # openvt -s -- echo "*** CDJ3K has not been tested with firmware v$RELEASE_MAJOR.$RELEASE_MINOR yet! CDJ3K magic key has uninstalled itself to prevent potential issues. Pleae restart your CDJ to boot normally."
#     # sleep 30d

#     exit 0
# fi

# Check for magic key sequence

/home/root/extra/subucom_check /dev/${SUBUCOM_DEVNAME}

# Run custom package from USB if required

testmode=off
if [ -f /tmp/testmode ] ; then
    testmode=`cat /tmp/testmode`

    if [ "$testmode" = "package_usb" ] ; then

        check_usb_package
        stop_cdj
        extract_package_to_tmp
        tweak_environment

        echo "Running package.sh..."

        cd /tmp
        ./package.sh

    fi

fi

exit 0

####################################################################################### 
