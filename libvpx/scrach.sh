#!/bin/bash
#
# brew install automake
#

rm -rf output/*

export SRCFOLDER=`pwd`

cd libvpx-1.16.0

#TOOLCHAIN
export TOOLCHAIN="/Applications/Xcode.app/Contents/Developer"

#OPENSSL
export OUTPUT_DIR=`pwd`/../output

make_ios() {

  make clean

  export CC=clang
  export CXX=clang++
  export AS=$CC
  export PLATFORM=$1
  export ARCH=$2
  export OUTTYPE=$5
  export CFLAGS=$7
  export CXXFLAGS=$7
  export CPPFLAGS=$7
  export OBJCFLAGS=$7
  export ASFLAGS=$7
  export LDFLAGS=$7
  export SYSROOT=`xcrun --sdk $6 --show-sdk-path`
  export ARCHGCC=$3

  ./configure \
    --target=$ARCHGCC \
    --disable-install-bins \
    --disable-install-libs \
    --disable-examples \
    --disable-tools \
    --disable-docs \
    --disable-shared \
    --enable-vp8 \
    --enable-vp9 \
    --enable-multithread \
    --as=yasm

  make
  mkdir -p ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}

  find . -name '*.a' -print | xargs -I % -t cp % ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/.
  find . -name '*.h' | cpio -pdmu ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/.
}

#ABI simulator
make_ios iphoneos-cross arm64 arm64-darwin-gcc "iPhoneSimulator.sdk" "iOSSim" iphonesimulator "-miphonesimulator-version-min=11.0 -arch arm64"

#ABI arm64
make_ios ios64-cross arm64 arm64-darwin-gcc "iPhoneOS.sdk" "iOS" iphoneos26.0 "-miphoneos-version-min=11.0 -arch arm64"
