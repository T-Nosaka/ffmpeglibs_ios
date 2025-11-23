#!/bin/bash

#brew install meson

#TOOLCHAIN
export TOOLCHAIN="/Applications/Xcode.app/Contents/Developer/Platforms/"
export SVTAV1=dav1d-1.5.1
export OUTPUT_DIR=`pwd`/output


make_ios() {
  ARCH=$1
  export CROSS_TOP=$TOOLCHAIN$2
  export CROSS_SDK=$3
  export OUTTYPE=$4
  export CROSSFILE=$5
  export MESONEXT=$6

  cd dav1d-1.5.1

  rm -rf build
  mkdir build && cd build
  meson setup --cross-file=$CROSSFILE --default-library=static $MESONEXT
  ninja

  mkdir -p ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}
  cp src/*.a ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/.
  cp -rp ../include ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/.
  cp -rp include/* ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/include/.

  cd ../..

}

#Rebuild
rm -rf output/*

#ABI simulator
make_ios arm64 "/Platforms/iPhoneSimulator.platform/Developer" "iPhoneSimulator.sdk" "iOSSim" "`pwd`/arm64-iPhoneSimulator.meson" ""

#ABI iphone
make_ios arm64 "/Platforms/iPhoneOS.platform/Developer" "iPhoneOS.sdk" "iOS" "../package/crossfiles/arm64-iPhoneOS.meson" ""
