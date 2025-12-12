# ffmpeglibs_ios
ffmpeg static library build script for iphone.
To integrate this into your project, you need to configure the Header Search Paths and Library Search Paths.
## Header Search Path
### iPhone Simulater
```
$(PROJECT_DIR)/ffmpeglib/ffmpeg/output/arm64/iOSSim
$(PROJECT_DIR)/ffmpeglib/ffmpeg/output/arm64/iOSSim/fftools
```
### iPhone
```
$(PROJECT_DIR)/ffmpeglib/ffmpeg/output/arm64/iOS
$(PROJECT_DIR)/ffmpeglib/ffmpeg/output/arm64/iOS/fftools
```
## Library Search Paths
### iPhone Simulater
```
$(PROJECT_DIR)/ffmpeglib/ffmpeg/output/arm64/iOSSim
$(PROJECT_DIR)/ffmpeglib/libsvtav1/output/arm64/iOSSim
$(PROJECT_DIR)/ffmpeglib/vvenc/output/arm64/iOSSim
$(PROJECT_DIR)/ffmpeglib/dav1d/output/arm64/iOSSim
$(PROJECT_DIR)/ffmpeglib/fdk-aac/output/arm64/iOSSim
$(PROJECT_DIR)/ffmpeglib/libsdl/output/arm64/iOSSim
$(PROJECT_DIR)/ffmpeglib/cJSON/output/arm64/iOSSim
```
### iPhone
```
$(PROJECT_DIR)/ffmpeglib/ffmpeg/output/arm64/iOS
$(PROJECT_DIR)/ffmpeglib/libsvtav1/output/arm64/iOS
$(PROJECT_DIR)/ffmpeglib/vvenc/output/arm64/iOS
$(PROJECT_DIR)/ffmpeglib/dav1d/output/arm64/iOS
$(PROJECT_DIR)/ffmpeglib/fdk-aac/output/arm64/iOS
$(PROJECT_DIR)/ffmpeglib/libsdl/output/arm64/iOS
$(PROJECT_DIR)/ffmpeglib/cJSON/output/arm64/iOS
```
## Additionally, specify the following link libraries.
### Other Linker Flags
```
-lavcodec
-lswscale
-lswresample
-lavutil
-lavformat
-lavfilter
-lavdevice
-ldav1d
-lSvtAv1Enc
-lvvenc
-lfdk-aac
-lSDL2
-lcjson
```
## ready build environment
requires xcode.
switch full xcode develop
```
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```
## libsvtav1
### Requires cmake 3.16
https://cmake.org/files/v3.16/cmake-3.16.0-Darwin-x86_64.dmg
### build
```
wget https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v3.1.2/SVT-AV1-v3.1.2.tar.gz
tar -xvf SVT-AV1-v3.1.2.tar.gz
./iosscrach.sh
./iossimscrach.sh
```
## dav1d
### Requires meson
```
brew install meson
```
### build
```
wget https://github.com/videolan/dav1d/archive/refs/tags/1.5.1.tar.gz
tar -xvf 1.5.1.tar.gz
./scrach.sh
```
## fdk-aac
### build
```
wget https://github.com/mstorsjo/fdk-aac/archive/refs/tags/v2.0.3.tar.gz
tar -xvf v2.0.3.tar.gz
./iosscrach.sh
./iossimscrach.sh
```
## libsdl
### Requires cmake 3.24
It appears that when multiple installations of CMake occur, they are installed into locations such as /Applications/CMake.app and /Applications/CMake 2.app.
Since the environment changes depending on the order of installation, please adjust the CMAKE environment variable setting in scrach.sh.

https://cmake.org/files/v3.24/cmake-3.24.0-macos-universal.dmg
### build
```
wget https://github.com/libsdl-org/SDL/releases/download/release-2.32.2/SDL2-2.32.2.tar.gz
tar -xvf SDL2-2.32.2.tar.gz
./iosscrach.sh
./iossimscrach.sh
```
## vvenc
### build
```
wget https://github.com/fraunhoferhhi/vvenc/archive/refs/tags/v1.13.1.tar.gz
tar -xvf v1.13.1.tar.gz
./iosscrach.sh
./iossimscrach.sh
```
## cjson
### build
```
wget https://github.com/DaveGamble/cJSON/archive/refs/tags/v1.7.18.tar.gz
tar -xvf v1.7.18.tar.gz
./iosscrach.sh
./iossimscrach.sh
```
## ffmpeg
### Requires automake 1.18.1
```
brew install automake
```
### download
```
wget https://www.ffmpeg.org/releases/ffmpeg-8.0.tar.gz
```
### Building bin2c
> Starting with FFmpeg 8.0, `textformat`, `resources`, and `graph` have been added to `fftools`.
> The `graph.css` and `graph.html` files located within `resources` must be converted into C source code using `bin2c` (a program created within `ffbuild`) and then compiled.
```
cd ffbuild
cc bin2c.c -o bin2c
cd ..
cd fftools/resources
../../ffbuild/bin2c graph.css graph.css.c
../../ffbuild/bin2c graph.html graph.html.c
```
### build
```
./scrach.sh
```
# example ffmpeg
```
import ffmpeglib

...

let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(resource.originalFilename)
PHAssetResourceManager.default().writeData(for: resource, toFile: fileURL, options: nil) { error in
    if let error = error {
        print("Error: \(error)")
    } else {
        print("Saved video to: \(fileURL)")
    }
}
                            
let output = FileManager.default.temporaryDirectory
        .appendingPathComponent("output_av1.mp4")

let args = [
        "ffmpeg",
        "-i", fileURL.path,
        "-c:v", "libsvtav1",
        "-preset", "8",
        "-crf", "40",
        "-c:a", "libfdk_aac", "-b:a", "128k",
        "-y",
        output.path
    ]
                            
let conv = ffmpeglib.Convert()
let convresult = conv.go(args: args) { start, cur, pts in
    print(" start: \(start), cur: \(cur), pts: \(pts) ")
    return true
}
```
# example ffplay
```
    let ffplay = ffmpeglib.Play()
    ffplay.setExtCallback( onexit: {
        // control stop
        return true
    },onclock: { pos, clock, pause in
        // display duration time
        print( "\(pos),\(clock)" )
    },upload_texture_cb: { width, height, format, pixelsPointer, pitch in
        // pixel data rgb24
//        let r = pixelsPointer[0]
//        let g = pixelsPointer[1]
//        let b = pixelsPointer[2]
    },oncontrol: { control, fargs in
        // control play
//        control.pointee = 1
//        control.advanced(by: 1).pointee = 2
//        fargs.pointee = 3.14159
        return false
    },readyaudiodevice: { channel,sample_rate in
        // ready autdio device
        return true
    },onstartaudio: {
        // on start audio.
    },onstopaudio: {
        // on stop audio.
    },update_subtile_cb: {
        // not implement.
    })
    let ret = ffplay.play(strfilename: fileURL.path, vfilter: "", afilter: "")

```
## ⚠️ License Notice

This project, `ffmpeglibs_ios`, is structured with dual licensing due to the inclusion of source code derived from FFmpeg's `fftools`.

### 1. General Project License (MIT)

The majority of the project, including build scripts, configuration files, and custom Objective-C/Swift wrapper code, is licensed under the **MIT License**. This allows users maximum freedom for usage, modification, and redistribution.

---

### 2. GNU General Public License (GPL) Portion

The source files located within the `ffmpeglib` directory, which are either direct copies or modifications of source code from FFmpeg's `fftools` (such as files related to `ffplay`), are licensed under the **GNU General Public License (GPL) version 2.1 or later**.

#### User Obligations:

If you utilize these GPL-licensed files in your application:

* **Your application may become subject to the GPL's requirements.**
* The GPL is a strong copyleft license, meaning you may be obligated to provide the source code of your derived work (your application) to end-users upon request.
* The necessary GPL-2.0 license text can be found in the `COPYING` file in this repository.

---

### 3. Disclaimer and Responsibility

* **By using this project, you acknowledge and agree that legal compliance (including adherence to the GPL) is solely your responsibility.**
* The project maintainer makes no warranty regarding the legal implications of distributing applications built using this repository. Please consult legal counsel if you have concerns about distributing GPL-licensed binaries.
