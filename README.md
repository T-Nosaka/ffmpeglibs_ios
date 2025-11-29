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
$(PROJECT_DIR)/ffmpeglib/dav1d/output/arm64/iOSSim
$(PROJECT_DIR)/ffmpeglib/fdk-aac/output/arm64/iOSSim
$(PROJECT_DIR)/ffmpeglib/libsdl/output/arm64/iOSSim
```
### iPhone
```
$(PROJECT_DIR)/ffmpeglib/ffmpeg/output/arm64/iOS
$(PROJECT_DIR)/ffmpeglib/libsvtav1/output/arm64/iOS
$(PROJECT_DIR)/ffmpeglib/dav1d/output/arm64/iOS
$(PROJECT_DIR)/ffmpeglib/fdk-aac/output/arm64/iOS
$(PROJECT_DIR)/ffmpeglib/libsdl/output/arm64/iOS
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
-lfdk-aac
-lSDL2
```
## libsvtav1
### Requires cmake 3.16
### build
```
wget https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v3.1.2/SVT-AV1-v3.1.2.tar.gz
tar -xvf SVT-AV1-v3.1.2.tar.gz
./iosscrach.sh
./iossimscrach.sh
```
## dav1d
### Requires meson
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
### build
```
wget https://github.com/libsdl-org/SDL/releases/download/release-2.32.2/SDL2-2.32.2.tar.gz
tar -xvf SDL2-2.32.2.tar.gz
./iosscrach.sh
./iossimscrach.sh
```
## ffmpeg
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
# example
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
