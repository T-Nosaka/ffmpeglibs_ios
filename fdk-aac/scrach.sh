#!/bin/bash

#TOOLCHAIN
export TOOLCHAIN="/Applications/Xcode.app/Contents/Developer/Platforms/"
export FDKAAC=fdk-aac-2.0.3
export OUTPUT_DIR=`pwd`/output
export MAKE=make
export CMAKE=cmake


make_ios() {
  ARCH=$1
  export OUTTYPE=$3

  rm -rf makegenerate/${ARCH}/${OUTTYPE}

  ${CMAKE} \
  -H${FDKAAC} \
  -Bmakegenerate/${ARCH} \
  -DBUILD_SHARED_LIBS=OFF \
  -DENABLE_CLI=OFF \
  -DSTATIC_LINK_CRT=ON \
  -DLINT=OFF \
  -DCMAKE_VERBOSE_MAKEFILE=TRUE \
  -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_ASM_NASM_COMPILER=clang \
  -DCMAKE_ASM=clang \
  -DCMAKE_MAKE_PROGRAM=${MAKE} \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_MACOSX_BUNDLE=NO \
  -DCMAKE_OSX_SYSROOT=${TOOLCHAIN}${2} \
  -DCMAKE_SYSTEM_NAME=Darwin \
  -DCMAKE_VERBOSE_MAKEFILE=TRUE \
  -DCMAKE_OSX_ARCHITECTURES=$1

  cd makegenerate/${ARCH}
  ${MAKE}
  mkdir -p ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}

  find . -name '*.a' -print | xargs -I % -t cp % ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/.
  cp -rp ../../${FDKAAC}/libAACenc/include ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/fdk-aac
  cp -rp ../../${FDKAAC}/libAACdec/include/* ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/fdk-aac/.
  cp -rp ../../${FDKAAC}/libSYS/include/* ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/fdk-aac/.
}

#Rebuild
rm -rf makegenerate
rm -rf output/*

#ABI simulator
make_ios arm64 "iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk" "iOSSim"

#ABI iphone
make_ios arm64 "iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk" "iOS"
