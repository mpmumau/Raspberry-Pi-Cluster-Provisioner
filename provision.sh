#!/bin/bash
#
# File: provision.sh
#
# This shell script provisions a series of 8 Raspbian system images to disk, 
# in sequential order.
#
# Created: Nov. 16, 2017
# Author: Matt Mumau <mpmumau@gmail.com>
#

# Util functions
function array_count()
{
    count=0
    while [ "x${SYSTEM_NAMES[count]}" != "x" ]
    do
       count=$(( $count + 1 ))
    done

    echo "$count"
}

# Image and system names
SYSTEM_NAMES=(
        'red'
        'yellow'
        'purple'
        'green'
        'white'
        'blue'
        'orange'
        'black'
    )
SYSTEM_COUNT=$(array_count $SYSTEM_NAMES)

TMP_DIR='/tmp/picluster'
ORIGINAL_DIR="$TMP_DIR/original"

if [ ! -d $TMP_DIR ]; then
    mkdir $TMP_DIR
fi

# Raspbian configuration
RASPBIAN_LATEST_URL='https://downloads.raspberrypi.org/raspbian_lite_latest'
RASPBIAN_FILE_ALIAS='raspbian-latest'
RASPBIAN_IMAGE_FILE="$TMP_DIR/$RASPBIAN_FILE_ALIAS.img"
RASPBIAN_ZIP_FILE="$TMP_DIR/$RASPBIAN_FILE_ALIAS.zip"

BOOT_OFFSET_BYTES=0
BOOT_SIZE_BYTES=0
SYS_OFFSET_BYTES=0

# Get the latest Raspbian image and save it to disk.
function get_raspbian_img()
{
    if [ ! -e "$RASPBIAN_IMAGE_FILE" ]; then
        wget -O $RASPBIAN_ZIP_FILE $RASPBIAN_LATEST_URL
        unzip $RASPBIAN_ZIP_FILE -d ./
        rm $RASPBIAN_ZIP_FILE

        TMP_IMAGE_FILE=$(find . -type f -name "*.img")
        mv $TMP_IMAGE_FILE $RASPBIAN_IMAGE_FILE
    fi
}

function set_raspbian_img_data()
{
    SECTOR_SIZE=$(fdisk -l $RASPBIAN_IMAGE_FILE | awk 'FNR == 2 { print $8 }')
    BOOT_OFFSET=$(fdisk -l $RASPBIAN_IMAGE_FILE | awk 'FNR == 9 { print $2 }')
    BOOT_END=$(fdisk -l $RASPBIAN_IMAGE_FILE | awk 'FNR == 9 { print $3 }')
    BOOT_SIZE="$(($BOOT_END - $BOOT_OFFSET))"
    SYS_OFFSET=$(fdisk -l $RASPBIAN_IMAGE_FILE | awk 'FNR == 10 { print $2 }')
    
    BOOT_OFFSET_BYTES="$(($BOOT_OFFSET * $SECTOR_SIZE))"
    BOOT_SIZE_BYTES="$(($BOOT_SIZE * $SECTOR_SIZE))"
    SYS_OFFSET_BYTES="$(($SYS_OFFSET * $SECTOR_SIZE))"
}

# Make global configuration changes to the base image
function modify_global_image()
{
    if [ ! -d $ORIGINAL_DIR ]; then
        mkdir $ORIGINAL_DIR
    fi

    BOOT_DIR="$ORIGINAL_DIR/boot"
    SYS_DIR="$ORIGINAL_DIR/sys"

    mkdir $BOOT_DIR
    mkdir $SYS_DIR

    #echo "sector size: $SECTOR_SIZE | boot offset: $BOOT_OFFSET | boot offset bytes: $BOOT_OFFSET_BYTES | sys offset: $SYS_OFFSET | sys_offset bytes: $SYS_OFFSET_BYTES | boot end: $BOOT_END | boot size: $BOOT_SIZE | boot size bytes: $BOOT_SIZE_BYTES"
     mount -v -o offset="$BOOT_OFFSET_BYTES",sizelimit="$BOOT_SIZE_BYTES" -t vfat "$RASPBIAN_IMAGE_FILE" $BOOT_DIR
     mount -v -o offset="$SYS_OFFSET_BYTES" -t ext4 "$RASPBIAN_IMAGE_FILE" $SYS_DIR

     touch "$BOOT_DIR/ssh"

     umount $BOOT_DIR
     umount $SYS_DIR
}

function modify_individual_images()
{
    OUTPUT_DIR="./output"
    if [ ! -d $OUTPUT_DIR ]; then
        mkdir $OUTPUT_DIR
    fi

    for i in `seq 1 $SYSTEM_COUNT`;
    do
        cp $RASPBIAN_IMAGE_FILE "$OUTPUT_DIR/image_$i.img"
        read -p "Press enter to continue..."
    done
}

# Main execution
get_raspbian_img
set_raspbian_img_data
modify_global_image
modify_individual_images

#rm -r $TMP_DIR
