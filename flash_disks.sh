#!/bin/bash
#
# File: flash_disks.sh
#
# This shell script provisions a series of 8 Raspbian system images to disk, 
# in sequential order.
#
# Created: Nov. 16, 2017
# Author: Matt Mumau <mpmumau@gmail.com>
#

# Include various utility functions
source utils.sh

# Console functions

function echo_section_title()
{
    echo "============================================"
    echo "$1"
    echo "============================================"
}

function echo_subhead()
{
    echo "--------------------------------------------"
    echo "$1"
    echo "--------------------------------------------"
}

# Define directories used by the provisioning process.
TMP_DIR='./tmp'
if [ ! -d $TMP_DIR ]; then
    mkdir $TMP_DIR
fi

MOUNT_DIR="$TMP_DIR/mount"
if [ ! -d $MOUNT_DIR ]; then
    mkdir $MOUNT_DIR
fi

BOOT_DIR="$MOUNT_DIR/boot"
if [ ! -d $BOOT_DIR ]; then
    mkdir $BOOT_DIR
fi

SYS_DIR="$MOUNT_DIR/sys"
if [ ! -d $SYS_DIR ]; then
    mkdir $SYS_DIR
fi

OUT_DIR="./out"
if [ ! -d $OUT_DIR ]; then
    mkdir $OUT_DIR
fi

# Variables to store the values that represent disk image data.
BOOT_OFFSET_BYTES=0
BOOT_SIZE_BYTES=0
SYS_OFFSET_BYTES=0

# Raspbian configuration
RASPBIAN_LATEST_URL='https://downloads.raspberrypi.org/raspbian_lite_latest'
RASPBIAN_FILE_ALIAS='raspbian-latest'
RASPBIAN_IMAGE_FILE="./$RASPBIAN_FILE_ALIAS.img"
RASPBIAN_ZIP_FILE="$TMP_DIR/$RASPBIAN_FILE_ALIAS.zip"

# Image and system names
SYSTEM_NAMES=(
    'orange'
    'blue'
    'black'
    'purple'
    'red'
    'yellow'
    'white'
    'green'
)
SYSTEM_COUNT=$(array_count ${SYSTEM_NAMES[@]})

SYSTEM_USER_NAME="pirate"

# Returns the system name from the systems array for the given number.
function get_system_name()
{
    echo ${SYSTEM_NAMES[$1]}
}

# Get the latest Raspbian image and save it to disk.
function get_raspbian_img()
{
    if [ -e "$RASPBIAN_IMAGE_FILE" ]; then
        return
    fi

    wget -O $RASPBIAN_ZIP_FILE $RASPBIAN_LATEST_URL
    unzip $RASPBIAN_ZIP_FILE -d ./
    rm $RASPBIAN_ZIP_FILE

    TMP_IMAGE_FILE=$(find . -type f -name "*.img")
    mv $TMP_IMAGE_FILE $RASPBIAN_IMAGE_FILE
}

function set_raspbian_img_data()
{
    SECTOR_SIZE=$(fdisk -l $RASPBIAN_IMAGE_FILE | awk 'FNR == 2 { print $8 }')
    BOOT_OFFSET=$(fdisk -l $RASPBIAN_IMAGE_FILE | awk 'FNR == 9 { print $2 }')
    BOOT_END=$(fdisk -l $RASPBIAN_IMAGE_FILE | awk 'FNR == 9 { print $3 }')
    SYS_OFFSET=$(fdisk -l $RASPBIAN_IMAGE_FILE | awk 'FNR == 10 { print $2 }')
    BOOT_SIZE="$(($BOOT_END - $BOOT_OFFSET))"
    
    BOOT_OFFSET_BYTES="$(($BOOT_OFFSET * $SECTOR_SIZE))"
    BOOT_SIZE_BYTES="$(($BOOT_SIZE * $SECTOR_SIZE))"
    SYS_OFFSET_BYTES="$(($SYS_OFFSET * $SECTOR_SIZE))"
}

# Make global configuration changes to the base image
function modify_global_image()
{
    echo_subhead "Configuring global image"

    #echo "sector size: $SECTOR_SIZE | boot offset: $BOOT_OFFSET | boot offset bytes: $BOOT_OFFSET_BYTES | sys offset: $SYS_OFFSET | sys_offset bytes: $SYS_OFFSET_BYTES | boot end: $BOOT_END | boot size: $BOOT_SIZE | boot size bytes: $BOOT_SIZE_BYTES"
    mount -v -o offset="$BOOT_OFFSET_BYTES",sizelimit="$BOOT_SIZE_BYTES" -t vfat "$RASPBIAN_IMAGE_FILE" $BOOT_DIR
    mount -v -o offset="$SYS_OFFSET_BYTES" -t ext4 "$RASPBIAN_IMAGE_FILE" $SYS_DIR

    # Enable SSH at boot
    touch "$BOOT_DIR/ssh"

    # Make Pi ssh directory
    PI_SSH_DIR="$SYS_DIR/home/$SYSTEM_USER_NAME/.ssh"
    if [ ! -d $PI_SSH_DIR ]; then
        mkdir $PI_SSH_DIR
        chown -R 1000:1000 $PI_SSH_DIR
        chmod -R 700 $PI_SSH_DIR
    fi

    # Configure SSH keys
    SSH_PUBLIC_KEY="$TMP_DIR/id_rsa.pub"
    SSH_PRIVATE_KEY="$TMP_DIR/id_rsa"
    ssh-keygen -f $SSH_PRIVATE_KEY -t rsa -b 4096 -N ''
    mv $SSH_PUBLIC_KEY "$PI_SSH_DIR/authorized_keys"
    mv $SSH_PRIVATE_KEY "$OUT_DIR/rpicluster_key"

    sync

    umount $BOOT_DIR
    umount $SYS_DIR
}

function modify_individual_image()
{
    i=$1

    TMP_SYS_NAME=$(get_system_name $(($i - 1)))
    TMP_HOST_NAME="rpicluster_$TMP_SYS_NAME"

    echo_section_title "Provisioning: $TMP_HOST_NAME"

    echo "Insert the disk to provision, then run fdisk to get its path."
    read -p "Press enter when disk inserted..."
    read -p "Enter the path to the disk to provision: " USER_DISK_PATH

    echo_subhead "Provision Config"
    printf "Hostname: \t$TMP_HOST_NAME\n"
    printf "Disk: \t\t$USER_DISK_PATH\n"
    echo "--------------------------------------------"
    echo "*IMPORTANT* Check that this is correct!"
    read -p "Press enter to continue..."

    RASPBIAN_TMP_IMAGE_FILE="$TMP_DIR/raspbian-image-tmp.img"
    cp $RASPBIAN_IMAGE_FILE $RASPBIAN_TMP_IMAGE_FILE

    sync

    mount -v -o offset="$BOOT_OFFSET_BYTES",sizelimit="$BOOT_SIZE_BYTES" -t vfat "$RASPBIAN_TMP_IMAGE_FILE" $BOOT_DIR
    mount -v -o offset="$SYS_OFFSET_BYTES" -t ext4 "$RASPBIAN_TMP_IMAGE_FILE" $SYS_DIR

    echo "$TMP_HOST_NAME" > "$SYS_DIR/etc/hostname"

    SSHD_CONFIG_TMP="$TMP_DIR/sshd_config.tmp.$i"
    cp "./config/sshd_config" $SSHD_CONFIG_TMP
    replace_token "PORT_NUM" "6540$i" $SSHD_CONFIG_TMP
    cp $SSHD_CONFIG_TMP "$SYS_DIR/etc/ssh/sshd_config"
    rm $SSHD_CONFIG_TMP

    sync

    umount $BOOT_DIR
    umount $SYS_DIR

    dd bs=1M if="$RASPBIAN_TMP_IMAGE_FILE" of="$USER_DISK_PATH" conv=fsync status=progress

    sync

    rm $RASPBIAN_TMP_IMAGE_FILE

    echo "Provisioning complete. You may now remove the disk."
    read -p "Press enter to continue..."
}

# Main execution
get_raspbian_img
set_raspbian_img_data

modify_global_image

for s in `seq 1 $SYSTEM_COUNT`;
do
    modify_individual_image $s
done

rm -r $TMP_DIR
