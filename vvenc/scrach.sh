#!/bin/bash

#TOOLCHAIN
export TOOLCHAIN="/Applications/Xcode.app/Contents/Developer/Platforms/"
export VVENC=vvenc-1.13.1
export OUTPUT_DIR=`pwd`/output
export MAKE=make
export CMAKE=cmake


make_ios() {
  ARCH=$1
  export OUTTYPE=$3

  rm -rf makegenerate/${ARCH}/${OUTTYPE}

  ${CMAKE} \
  -H${VVENC} \
  -Bmakegenerate/${ARCH} \
  -DBUILD_SHARED_LIBS=OFF \
  -DVVENC_LIBRARY_ONLY=ON \
  -DSTATIC_LINK_CRT=ON \
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
  -DCMAKE_OSX_ARCHITECTURES=$1 \
  -DCMAKE_C_FLAGS=$4 \
  -DCMAKE_CXX_FLAGS=$4

  cd makegenerate/${ARCH}
  ${MAKE}
  mkdir -p ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}

  find ../../${VVENC} -name '*.a' -print | xargs -I % -t cp % ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/.
  cp -r ../../${VVENC}/include ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/.
  find . -name '*.h' -print | xargs -I % -t cp % ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/include/vvenc/.
}

