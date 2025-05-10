#!/bin/bash
# Script to install and build kernel, busybox, and prepare rootfs

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]; then
    echo "Using default directory ${OUTDIR} for output"
else
    OUTDIR=$1
    echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}
cd "$OUTDIR"

# Clone and build the Linux kernel
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    echo "Cloning Linux kernel ${KERNEL_VERSION}"
    git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi

if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd ${OUTDIR}/linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs
fi

echo "Copying kernel Image"
cp ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image /tmp/aesd-autograder/Image

# Prepare the root filesystem
echo "Creating root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]; then
    echo "Removing existing rootfs"
    sudo rm -rf ${OUTDIR}/rootfs
fi

mkdir -p ${OUTDIR}/rootfs
cd ${OUTDIR}/rootfs
mkdir -p bin dev etc home lib proc sbin sys tmp usr/bin usr/lib usr/sbin var lib64

# Clone and build BusyBox
cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]; then
    git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    make distclean
    make defconfig
else
    cd busybox
fi

make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} install

# Get the sysroot
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)

# Copy library dependencies
cd ${OUTDIR}/rootfs
mkdir -p lib lib64

echo "Copying library dependencies from $SYSROOT"
cp -a ${SYSROOT}/lib/ld-linux-aarch64.so.1 lib/
cp -a ${SYSROOT}/lib64/libc.so.6 lib64/
cp -a ${SYSROOT}/lib64/libm.so.6 lib64/
cp -a ${SYSROOT}/lib64/libresolv.so.2 lib64/

# Create device nodes
echo "Creating device nodes"
sudo mknod -m 666 dev/null c 1 3
sudo mknod -m 622 dev/console c 5 1

# Build writer utility
echo "Building writer"
cd ${FINDER_APP_DIR}
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

# Copy scripts and config to target
echo "Copying finder app files"
cp writer ${OUTDIR}/rootfs/home/
cp finder.sh finder-test.sh autorun-qemu.sh ${OUTDIR}/rootfs/home/
mkdir -p ${OUTDIR}/rootfs/home/conf
cp conf/assignment.txt conf/username.txt ${OUTDIR}/rootfs/home/conf/
sed -i 's|\.\./conf/assignment.txt|conf/assignment.txt|' ${OUTDIR}/rootfs/home/finder-test.sh

# Set ownership and link init
echo "Setting root ownership"
cd ${OUTDIR}/rootfs
sudo ln -s bin/busybox init
sudo chown -R root:root .

# Create initramfs
echo "Creating initramfs"
find . | cpio -H newc -ov --owner root:root | gzip > ${OUTDIR}/initramfs.cpio.gz
