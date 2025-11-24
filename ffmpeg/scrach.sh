#!/bin/bash
#
# brew install automake
#

rm -rf output/*

export SRCFOLDER=`pwd`

cd ffmpeg-8.0

#TOOLCHAIN
export TOOLCHAIN="/Applications/Xcode.app/Contents/Developer"

#OPENSSL
export OUTPUT_DIR=`pwd`/../output

make_ios() {

  make clean

  export CC=clang
  export CXX=clang++
  export PLATFORM=$1
  export ARCH=$2
  export OUTTYPE=$5
  export extra_cflags=$7
  export LDFLAGS=$7
  export SYSROOT=`xcrun --sdk $6 --show-sdk-path`

  #Library paths
  export C_INCLUDE_PATH=""
  export C_INCLUDE_PATH=${C_INCLUDE_PATH}:${SRCFOLDER}/../fdk-aac/output/${ARCH}/${OUTTYPE}
  export C_INCLUDE_PATH=${C_INCLUDE_PATH}:${SRCFOLDER}/../libsvtav1/output/${ARCH}/${OUTTYPE}
  export C_INCLUDE_PATH=${C_INCLUDE_PATH}:${SRCFOLDER}/../dav1d/output/${ARCH}/${OUTTYPE}/include

  #for configure test module
  export LDFLAGS=${LDFLAGS}" -lstdc++"
  export LDFLAGS=${LDFLAGS}" -L"${SRCFOLDER}/../fdk-aac/output/${ARCH}/${OUTTYPE}
  export LDFLAGS=${LDFLAGS}" -L"${SRCFOLDER}/../libsvtav1/output/${ARCH}/${OUTTYPE}
  export LDFLAGS=${LDFLAGS}" -L"${SRCFOLDER}/../dav1d/output/${ARCH}/${OUTTYPE}

  EXTCODEC='--enable-libfdk-aac
          --enable-libdav1d
          --enable-libsvtav1'

  ./configure \
        --cc=${CC} \
        --arch=${ARCH} \
        --prefix=${OUTPUT_DIR} \
        --pkg-config=`pwd`/../pkgconfig.sh \
        --extra-libs="-lm" \
        --target_os="darwin" \
        --sysroot=${SYSROOT} \
        --enable-gpl \
        --enable-nonfree \
        --enable-cross-compile \
        --enable-pic \
        --disable-frei0r \
        --disable-ffplay \
        --disable-ffprobe \
        --disable-ffmpeg \
        --disable-programs \
        --disable-doc \
        --disable-htmlpages \
        --disable-manpages \
        --disable-podpages \
        --disable-txtpages \
        --disable-iconv \
        --disable-xlib \
        --disable-amf           \
        --disable-audiotoolbox  \
        --disable-cuda-llvm     \
        --disable-cuvid         \
        --disable-d3d11va       \
        --disable-dxva2         \
        --disable-ffnvcodec     \
        --disable-libdrm        \
        --disable-nvdec         \
        --disable-nvenc         \
        --disable-v4l2-m2m      \
        --disable-vaapi         \
        --disable-vdpau         \
        --disable-videotoolbox  \
        --disable-alsa           \
        --disable-appkit         \
        --disable-avfoundation   \
        --disable-bzlib          \
        --disable-coreimage      \
        --disable-metal          \
        --disable-sndio          \
        --disable-schannel       \
        --disable-sdl2           \
        --disable-securetransport \
        --disable-xlib           \
        --disable-zlib           \
        --disable-devices        \
        --disable-vulkan         \
        ${EXTCODEC}

  make
  mkdir -p ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}

  find . -name '*.a' -print | xargs -I % -t cp % ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/.
  find . -name '*.h' | cpio -pdmu ${OUTPUT_DIR}/${ARCH}/${OUTTYPE}/.
}

#ABI simulator
make_ios iphoneos-cross arm64 "/Platforms/iPhoneSimulator.platform/Developer" "iPhoneSimulator.sdk" "iOSSim" iphonesimulator "-miphonesimulator-version-min=13.0"

#ABI arm64
make_ios ios64-cross arm64 "/Platforms/iPhoneOS.platform/Developer" "iPhoneOS.sdk" "iOS" iphoneos26.0 "-miphoneos-version-min=13.0"
