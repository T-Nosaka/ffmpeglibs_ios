#!/bin/bash

#brew install cmake

#TOOLCHAIN
export TOOLCHAIN="/Applications/Xcode.app/Contents/Developer/Platforms/"
export SVTAV1=SVT-AV1-v3.1.2
export OUTPUT_DIR=`pwd`/output
export MAKE=make
export CMAKE=cmake


make_ios() {
  ARCH=$1
  export OUTTYPE=$3

  rm -rf makegenerate/${ARCH}/${OUTTYPE}

  ${CMAKE} \
  -H${SVTAV1} \
  -Bmakegenerate/${ARCH} \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTING=OFF \
  -DBUILD_APPS=OFF \
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

  find ../../${SVTAV1}/Bin/Release -name '*.a' -print | xargs -I % -t cp % ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/.
  cp -r ../../${SVTAV1}/Source/API/* ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/.
}

#Rebuild
rm -rf makegenerate
rm -rf output/*

#ABI simulator
make_ios arm64 "iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk" "iOSSim"

#ABI iphone
make_ios arm64 "iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk" "iOS"
