#!/bin/bash

. $(dirname $0)/../global_definitions

ROOT_BLKDEV=${ROOT_BLKDEV-/dev/mmcblk0}
BOOT_RESIZER=$(dirname $0)/../stage4/init_resize
BOOT_RESIZER_DEPLOYED=/usr/local/sbin/init_resize

deployed=${ROOT_PATH}${BOOT_RESIZER_DEPLOYED}

cmdline=$(cat $BOOT_PATH/cmdline.txt)

case $FSTYPE in
    btrfs)
        resizeTarget="/";
        aptPackage="btrfs-progs"
        ;;
    ext2|ext3|ext4)
        resizeTarget=${ROOT_PART=/dev/mmcblk0p2}
        aptPackage="e2fsprogs"
        ;;
    f2fs)
        resizeTarget=${ROOT_PART=/dev/mmcblk0p2}
        aptPackage="f2fs-tools"
        ;;

    *)
        resizeTarget=${ROOT_PART=/dev/mmcblk0p2}
        ;;
esac

echo "Installing packages via APT..."
# util-linux: findmnt
chroot $ROOT_PATH apt-get install -y parted util-linux $aptPackage

echo "Deploying boot resizer..."
cp $BOOT_RESIZER $deployed

chmod a+x ${ROOT_PATH}${BOOT_RESIZER_DEPLOYED}

if [ ${RESIZEFS_FIRSTBOOT:=1} -eq 1 ]; then
    echo "Updating $BOOT_PATH/cmdline.txt"
    if echo $cmdline | grep init=$BOOT_RESIZER_DEPLOYED ; then
        echo "cmdline.txt already configured."
    else
        echo ${cmdline}" init=$BOOT_RESIZER_DEPLOYED" > $BOOT_PATH/cmdline.txt
    fi
else
    echo "Skip configure firstboot resizefs option..."
fi

# workaround for fsck.f2fs missing "-y" option
#   Bugreport: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=883026
#   Solution: upgrade to unstable v1.10
if [ "$FSTYPE" = "f2fs" ];then
    for pkg in libf2fs0_1.10.0-1_arm64.deb \
               f2fs-tools_1.10.0-1_arm64.deb
    do
        wget -c -P $ROOT_PATH/ "http://ftp.debian.org/debian/pool/main/f/f2fs-tools/${pkg}"
        chroot $ROOT_PATH dpkg -i /${pkg}
    done
fi

echo "Done."

