#!/bin/bash
#
# brew install libtool
#

rm -rf output/*

export SRCFOLDER=`pwd`

cd zimg-release-3.0.6

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

  rm -rf autom4te.cache config.status configure
  ./autogen.sh
  ./configure \
    --with-sysroot=${SYSROOT} \
    --host=aarch64-apple-ios \
    --disable-simd \
    --disable-testapp \
    --disable-example

  sed -i.bak 's/^CPPFLAGS = -miphonesimulator-version-min=11.0 -arch arm64$/& -isysroot $(SYSROOT)/' Makefile
  sed -i.bak 's/^LDFLAGS = -miphonesimulator-version-min=11.0 -arch arm64$/& -isysroot $(SYSROOT)/' Makefile
  sed -i.bak 's/^CPPFLAGS = -miphoneos-version-min=11.0 -arch arm64$/& -isysroot $(SYSROOT)/' Makefile
  sed -i.bak 's/^LDFLAGS = -miphoneos-version-min=11.0 -arch arm64$/& -isysroot $(SYSROOT)/' Makefile

  make
  mkdir -p ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}

  find . -name '*.a' -print | xargs -I % -t cp % ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/.
  cp src/zimg/api/zimg.h ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/.
}

#ABI simulator
make_ios iphoneos-cross arm64 "/Platforms/iPhoneSimulator.platform/Developer" "iPhoneSimulator.sdk" "iOSSim" iphonesimulator "-miphonesimulator-version-min=11.0 -arch arm64"

#ABI arm64
make_ios ios64-cross arm64 "/Platforms/iPhoneOS.platform/Developer" "iPhoneOS.sdk" "iOS" iphoneos26.0 "-miphoneos-version-min=11.0 -arch arm64"
