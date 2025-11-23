# ffmpeglibs_ios
ffmpeg library build script for iphone

FFmpeg build script for iOS.

To integrate this into your project, you need to configure the **Header Search Paths** and **Library Search Paths**.

>Header Search Paths
```
$(PROJECT_DIR)/ffmpeglib/ffmpeg/output/arm64/iOSSim
$(PROJECT_DIR)/ffmpeglib/ffmpeg/output/arm64/iOSSim/fftools
```
>Library Search Paths
```
$(PROJECT_DIR)/ffmpeglib/ffmpeg/output/arm64/iOSSim
$(PROJECT_DIR)/ffmpeglib/libsvtav1/output/arm64/iOSSim
$(PROJECT_DIR)/ffmpeglib/dav1d/output/arm64/iOSSim
```

Additionally, specify the following link libraries.
>Other Linker Flags
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
```

## ffmpeg
https://www.ffmpeg.org/releases/ffmpeg-8.0.tar.gz

> Starting with FFmpeg 8.0, `textformat`, `resources`, and `graph` have been added to `fftools`.
> The `graph.css` and `graph.html` files located within `resources` must be converted into C source code using `bin2c` (a program created within `ffbuild`) and then compiled.

Building bin2c
```
cc bin2c.c -o bin2c

cd fftools/resources ../../ffbuild/bin2c graph.css graph.css.c ../../ffbuild/bin2c graph.html graph.html.c
```
## libsvtav1
- Requires cmake 3.16

https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v3.1.2/SVT-AV1-v3.1.2.tar.gz

## dav1d
- Requires meson

https://github.com/videolan/dav1d/archive/refs/tags/1.5.1.tar.gz
