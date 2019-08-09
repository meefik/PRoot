#!/bin/sh

set -e

if [ $# -ne 2 ]
then
    echo "Usage: $0 <arm|aarch64|x86|x86_64> <BUILD_ENV_DIR>"
    exit 1
fi

ARCH="$1"
BUILD_ENV_DIR=$(realpath "$2")
QEMU="qemu-$ARCH-static"
TALLOC_VERSION="2.1.8"
NCPU=$(grep -c ^processor /proc/cpuinfo)

which $QEMU > /dev/null || {
    echo "You need to install $QEMU to run this script. On Debian, run as root:"
    echo "apt install qemu-user"
    exit 1
}

if [ ! -e "$BUILD_ENV_DIR" ]
then
    mkdir -p "$BUILD_ENV_DIR"
    DEB_ARCH=$ARCH
    case "$ARCH" in
    arm)
        DEB_ARCH="armhf"
    ;;
    aarch64)
        DEB_ARCH="arm64"
    ;;
    x86)
        DEB_ARCH="i386"
    ;;
    x86_64)
        DEB_ARCH="amd64"
    ;;
    esac
    debootstrap --arch="$DEB_ARCH" --include=build-essential,python,qemu-user-static buster "$BUILD_ENV_DIR"
fi

#if [ $(grep -c "$BUILD_ENV_DIR/proc" /proc/mounts) -eq 0 ]
#then
#    mount -t proc proc "$BUILD_ENV_DIR/proc"
#fi

# build talloc
if [ ! -e "$BUILD_ENV_DIR/tmp/talloc.tar.gz" ]
then
    wget http://www.samba.org/ftp/talloc/talloc-$TALLOC_VERSION.tar.gz -O "$BUILD_ENV_DIR/tmp/talloc.tar.gz"
fi
if [ ! -e "$BUILD_ENV_DIR/tmp/talloc" ]
then
    tar xzf "$BUILD_ENV_DIR/tmp/talloc.tar.gz" -C "$BUILD_ENV_DIR/tmp"
fi

chroot "$BUILD_ENV_DIR" $QEMU /usr/bin/env sh -c "cd /tmp/talloc-$TALLOC_VERSION; ./configure build"
chroot "$BUILD_ENV_DIR" $QEMU /usr/bin/env sh -c "cd /tmp/talloc-$TALLOC_VERSION; ar rcs libtalloc.a bin/default/talloc*.o"

# build proot
if [ ! -e "$BUILD_ENV_DIR/tmp/proot" ]
then
  cp -r "$(dirname $0)/../src" "$BUILD_ENV_DIR/tmp/proot"
fi

chroot "$BUILD_ENV_DIR" $QEMU /usr/bin/env make -C /tmp/proot clean
chroot "$BUILD_ENV_DIR" $QEMU /usr/bin/env CPPFLAGS="-I/tmp/talloc-$TALLOC_VERSION" LDFLAGS="-L/tmp/talloc-$TALLOC_VERSION -static" make -C /tmp/proot glibc-version=glibc-2.18 -f GNUmakefile -j$NCPU
chroot "$BUILD_ENV_DIR" $QEMU /usr/bin/env strip -s "/tmp/proot/proot"
cp "$BUILD_ENV_DIR/tmp/proot/proot" ./proot-$ARCH

#umount "$BUILD_ENV_DIR/proc"
