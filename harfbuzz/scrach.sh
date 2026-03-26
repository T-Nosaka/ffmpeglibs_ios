#!/bin/bash

#brew install meson

#TOOLCHAIN
export TOOLCHAIN="/Applications/Xcode.app/Contents/Developer/Platforms/"
export HARFBUZZ=harfbuzz-12.3.2
export OUTPUT_DIR=`pwd`/output
export FREETYPE=`pwd`/../freetype
export PKG_CONFIG=`pwd`/pkgconfig.sh

make_ios() {
  ARCH=$1
  export CROSS_TOP=$TOOLCHAIN$2
  export OUTTYPE=$3
  export CROSSFILE=$4

  export CPATH=$CPATH:${FREETYPE}/output/arm64/iOS/include

  cd ${HARFBUZZ}

  rm -rf build
  mkdir build && cd build
  meson setup --reconfigure --cross-file=$CROSSFILE --default-library=static -Dfreetype=enabled -Dglib=disabled -Dicu=disabled -Dbenchmark=disabled -Dutilities=disabled -Ddocs=disabled -Dtests=disabled
  ninja

  mkdir -p ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}
  cp src/*.a ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/.
  cp -rp src ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/.

  cd ../..

}

#Rebuild
rm -rf output/*

#ABI simulator
make_ios arm64 "/Platforms/iPhoneSimulator.platform/Developer" "iOSSim" "`pwd`/arm64-iPhoneSimulator.meson"

#ABI iphone
make_ios arm64 "/Platforms/iPhoneOS.platform/Developer" "iOS" "`pwd`/arm64-iPhoneOS.meson"
