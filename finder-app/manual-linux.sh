#!/bin/bash
# Script to build kernel and initramfs for ARM64 QEMU
# Author: Siddhant Jajoo. Modified by: Karim

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-
FINDER_APP_DIR=$(realpath $(dirname $0))

if [ $# -lt 1 ]; then
    echo "Using default directory ${OUTDIR} for output"
else
    OUTDIR=$(realpath $1)
    echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p "${OUTDIR}"

cd "$OUTDIR"

# -------- Kernel --------
if [ ! -d "linux-stable" ]; then
    echo "Cloning Linux Kernel..."
    git clone ${KERNEL_REPO} --depth 1 --branch ${KERNEL_VERSION} linux-stable
fi

if [ ! -e linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Building Linux Kernel..."
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make -j$(nproc) ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
    cd ..
fi

echo "Copying kernel image..."
cp linux-stable/arch/${ARCH}/boot/Image .

# -------- Root Filesystem --------
echo "Setting up rootfs..."
cd "$OUTDIR"
if [ -d rootfs ]; then
    echo "Cleaning previous rootfs"
    sudo rm -rf rootfs
fi

mkdir -p rootfs/{bin,sbin,lib,lib64,usr/{bin,sbin},etc,proc,sys,dev,tmp,home}

# -------- BusyBox --------
if [ ! -d "busybox" ]; then
    echo "Cloning BusyBox..."
    for i in 1 2 3; do
        git clone git://busybox.net/busybox.git && break
        echo "BusyBox clone attempt $i failed. Retrying..."
        sleep 5
    done
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    make distclean
    make defconfig
else
    cd busybox
fi

make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${OUTDIR}/rootfs install
cd "$OUTDIR"

# -------- Libraries --------
echo "Copying library dependencies..."
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)

cd rootfs
mkdir -p lib lib64

cp ${SYSROOT}/lib/ld-linux-aarch64.so.1 lib/ || true
cp ${SYSROOT}/lib64/libc.so.6 lib64/ || true
cp ${SYSROOT}/lib64/libm.so.6 lib64/ || true
cp ${SYSROOT}/lib64/libresolv.so.2 lib64/ || true

# -------- Device Nodes --------
echo "Creating device nodes..."
sudo mknod -m 666 dev/null c 1 3
sudo mknod -m 600 dev/console c 5 1

# -------- Writer Utility --------
echo "Building writer..."
cd "${FINDER_APP_DIR}"
make clean
make CROSS_COMPILE=${CROSS_COMPILE} ARCH=${ARCH}
cp writer "${OUTDIR}/rootfs/home/"

# -------- Finder Scripts --------
echo "Copying scripts and configs..."
cp  finder.sh finder-test.sh ${OUTDIR}/rootfs/home/
cp -rf ../conf/ ${OUTDIR}/rootfs/home/

sed -i 's|\.\./conf|conf|' "${OUTDIR}/rootfs/home/finder-test.sh"

cp autorun-qemu.sh "${OUTDIR}/rootfs/home/"

# -------- Permissions --------
cd "${OUTDIR}/rootfs"
sudo chown -R root:root *

# -------- Initramfs --------
echo "Creating initramfs..."
find . | cpio -H newc -ov --owner root:root | gzip > "${OUTDIR}/initramfs.cpio.gz"

echo "Build complete. Kernel and initramfs are ready in ${OUTDIR}"
