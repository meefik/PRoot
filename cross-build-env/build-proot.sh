#!/bin/sh

ARCH="$1"
TALLOC_VERSION="2.1.8"
BUILD_ENV_DIR="slackware-$ARCH"

case "$ARCH" in
arm)
    QEMU="qemu-arm"
;;
x86)
    QEMU="qemu-i386"
;;
*)
    echo "Usage: $0 <arm|x86>"
    exit 1
;;
esac

if [ ! -e $BUILD_ENV_DIR ]
then
	echo "Run script init-build-env.sh first"
	exit 1
fi

PATH=`pwd`:$PATH
which proot > /dev/null || {
	echo "Please compile proot first, and copy it to the current directory"
	exit 1
}

# Build PRoot/ARM statically:
SRC=`cd ../src ; pwd`
if [ ! -e talloc-$ARCH ]
then
	[ -e talloc.tar.gz ] || wget http://www.samba.org/ftp/talloc/talloc-$TALLOC_VERSION.tar.gz -O talloc.tar.gz || exit 1
	rm -rf talloc
	tar xvf talloc.tar.gz || exit 1
	mv talloc-$TALLOC_VERSION talloc-$ARCH || exit 1
	cd talloc-$ARCH || exit 1
	rm -f libtalloc.a
	proot -R ../$BUILD_ENV_DIR -q $QEMU ./configure build || exit 1
	ar rcs libtalloc.a bin/default/talloc*.o || exit 1
	cd ..
fi

make -C $SRC clean
proot -R $BUILD_ENV_DIR -q $QEMU env CPPFLAGS="-I`pwd`/talloc-$ARCH" LDFLAGS="-L`pwd`/talloc-$ARCH -static" make -C $SRC glibc-version=glibc-2.18 -f GNUmakefile -j4 || exit 1
proot -R $BUILD_ENV_DIR -q $QEMU strip -s $SRC/proot
mv $SRC/proot $SRC/proot-$ARCH

