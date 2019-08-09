#!/bin/sh

ARCH="$1"
BUILD_ENV_DIR="slackware-$ARCH"

case "$ARCH" in
arm)
    BASE_URL="http://ftp.arm.slackware.com/slackwarearm/slackwarearm-14.1/slackware"
    SOURCE_DIR="ftp.arm.slackware.com"
    QEMU="qemu-arm"
;;
x86)
    BASE_URL="http://ftp.slackware.com/pub/slackware/slackware-14.1/slackware"
    SOURCE_DIR="ftp.slackware.com"
    QEMU="qemu-i386"
;;
*)
    echo "Usage: $0 <arm|x86>"
    exit 1
;;
esac

which qemu-arm > /dev/null || {
    echo "You need to install qemu-arm to run this script. On debian, run:"
    echo "sudo apt-get install qemu-user"
    exit 1
}

which wget > /dev/null || {
    echo "You need to install wget to run this script. On debian, run:"
    echo "sudo apt-get install wget"
    exit 1
}

PATH=`pwd`:$PATH
which proot > /dev/null || {
    echo "Please compile proot first, and copy it to the current directory"
    exit 1
}

echo "Slackware packages: "
PKGS=`cat slackware-devel.txt | tr '\n' ',' | sed 's@,@*,@g' | sed 's/,[*]$//' | sed 's/,$//'`
echo "$PKGS"

# Get Slackware/ARM packages:
echo "STAGE 1. Downloading packages... "
for DIR in a ap d e l n tcl
do
    wget -q -r -np -N --accept="$PKGS" $BASE_URL/$DIR/ || exit 1
done

rm -rf $BUILD_ENV_DIR
mkdir $BUILD_ENV_DIR || exit 1

# Extract only a minimal subset (ignore errors):
echo "STAGE 2. Unpacking packages... "
for DIR in a l; do
    find $SOURCE_DIR -type f -name '*.t?z' | xargs -n 1 tar -C $BUILD_ENV_DIR -x --exclude="dev/*" --exclude="lib/udev/devices/*" -f || exit 1
done

# Do a minimal post-installation setup:
echo "STAGE 3. Install packages... "
mv $BUILD_ENV_DIR/lib/incoming/* $BUILD_ENV_DIR/lib/ || exit 1
mv $BUILD_ENV_DIR/bin/bash4.new $BUILD_ENV_DIR/bin/bash || exit 1
ln -s /bin/bash $BUILD_ENV_DIR/bin/sh || exit 1
touch $BUILD_ENV_DIR/etc/ld.so.conf || exit 1
proot -q $QEMU -S $BUILD_ENV_DIR /sbin/ldconfig || exit 1

# Install all package correcty (ignore warnings):
find $SOURCE_DIR -type f -name '*.t?z' | xargs -n 1 proot -q $QEMU -S $BUILD_ENV_DIR -b $SOURCE_DIR /sbin/installpkg || exit 1
