#!/bin/bash

#
# This file is part of the Magic Phono project (https://magicphono.org/).
# Copyright (c) 2025 xorbxbx <xorbxbx@magicphono.org>
# 
# NOTE: Set MP_NOCLEAN=1 to leave tmp folder intact, useful for debugging.
#

make_firmware()
{
    echo "* Making firmware ...."

    NAME=$(echo "$1" | tr a-z A-Z)
    VERSION=`cat src/$1/scripts/VERSION`
    LOOP=$(sudo losetup -f)
    TMP=$(mktemp -d)

    echo "    Name: $NAME"
    echo "    Version: $VERSION"
    echo "    Temp folder: $TMP"

    # Copy scripts
     echo "* Copying scripts ...."
    cp -r src/$1/scripts/. $TMP

    # Merge in version
    FWFILE="CDJ3Kv$NAME$VERSION.UPD"
    
    # Make pdj.tar.gz if required
    if [ -d src/$1/pdj ]; then
        echo "* Making pdj.tar.gz ...."
	    tar --no-xattrs --exclude ".DS_Store" -czvf $TMP/pdj.tar.gz -C src/$1/pdj/ .
    fi

    # Make images
    echo "* Making images ...."
    genisoimage -R -J -input-charset utf-8 -o CDJ3K-RK3399.iso "$TMP"
	isoinfo -R -l -i CDJ3K-RK3399.iso

    genisoimage -R -J -input-charset utf-8 --graft-points -o $FWFILE images/CDJ3K-RK3399.iso=CDJ3K-RK3399.iso "$TMP"
    isoinfo -R -l -i $FWFILE
  
    # Make room for LUKS header
    echo "* Encrypting ...."
    dd if=/dev/zero bs=32M count=1 >> $FWFILE
    sudo losetup $LOOP $FWFILE
    sudo cryptsetup reencrypt \
        --batch-mode \
        --encrypt \
        --reduce-device-size 32M \
        --type luks1 \
        --cipher aes-xts-plain64 \
        --key-size 512 \
        --key-file aes256.key \
        $LOOP cdj_firmware
    # Cleanup
    echo "* Cleaning up ...."
    sudo losetup -d $LOOP
    if [ -z "${MP_NOCLEAN}" ]; then
        rm -rf $TMP
    else
        echo "* Leaving directory $TMP intact!"
    fi
    # Calculate CRC before writing magic trailer
    echo "* Calculating CRC ...."
    ./crc32.py $FWFILE > $FWFILE.crc32
    echo -n -e 'XDJ-RR0.00\x00' >> $FWFILE
    cat $FWFILE.crc32 >> $FWFILE

    echo "* Firmware created: $FWFILE"
}

clean()
{
    NAME=$(echo "$1" | tr a-z A-Z)

	rm -f CDJ3Kv$NAME*.UPD
	rm -f CDJ3Kv$NAME*.UPD.crc32
	rm -f CDJ3K-RK3399.iso
}


if [[ $# -ne 2 ]]; then
    echo 'Too many/few arguments, expecting two' >&2
    exit 1
fi

case $1 in
    build)
        make_firmware $2
        ;;
    clean)
        clean $2
        ;;
    *)
        echo 'Expected "build" or "clean"' >&2
        exit 1
esac
