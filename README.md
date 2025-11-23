# ffmpeglibs_ios
ffmpeg library for iphone

FFMpeg
https://www.ffmpeg.org/releases/ffmpeg-8.0.tar.gz

libsvtav1
cmake 3.16以上が必要
https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v3.1.2/SVT-AV1-v3.1.2.tar.gz

dav1d
need meson
https://github.com/videolan/dav1d/archive/refs/tags/1.5.1.tar.gz

---------------------------------------------------------------------------------------------------------
ffmpeg8.0から、fftoolsに textformatとresourcesとgraphが追加された
resourcesの中のgraph.cssとgraph.htmlは、bin2c という、ffbuildで作成されるプログラムで、cソースに変換してコンパイルする必要がある。

bin2cの構築
cc bin2c.c -o bin2c

cd fftools/resources
../../ffbuild/bin2c graph.css graph.css.c
../../ffbuild/bin2c graph.html graph.html.c

