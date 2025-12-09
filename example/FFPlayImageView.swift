//
//  FFPlayImageView.swift
//
//  Created by Takashi Nosaka on 2025/11/30.
//

import SwiftUI
import Combine

import ffmpeglib

///
/// ffplay画像モデル
///
class FFPlayImageViewModel: ObservableObject {
    
    //
    // 再生状態と制御
    //
    @Published var isplay : Bool = false
    @Published var reqpause : Bool = false
    // シーク要求
    private var reqseek : Bool = false
    private var nowseek:Double = 0.0

    //
    // 映像
    //
    @Published var image : CGImage? = nil

    //
    // メディア情報
    //
    @Published var format = "unknown"
    @Published var duration = Duration(attoseconds: 0)

    //
    // 現在値
    //
    @Published var position:Double = 0.0
    @Published var now:Duration = .seconds(0)
    
    //
    // メディア情報取得
    //
    func probe(_ filepath: URL ) {
        let mediainfo = ffmpeglib.Convert.parse(filepath: filepath.path)
        format = mediainfo["format"] as! String
        duration = .seconds( (mediainfo["duration"] as? Double)! )
    }

    //
    // シーク要求
    //
    func reqseek(_ nowtime:Double ) {
        nowseek = nowtime
        reqseek = true
    }
    
    ///
    /// 再生
    ///
    func play( filepath: URL ) {
        guard self.isplay == false else {return}
        
        self.isplay = true
        self.reqpause = false

        _ = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            await self.probe( filepath )
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo: CGBitmapInfo = [
                .byteOrder32Little,
                CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
            ]
            var callbacks = CGDataProviderDirectCallbacks(
                version: 0,
                getBytePointer:{ info in
                    UnsafeRawPointer(info)
                    },
                releaseBytePointer: nil,
                getBytesAtPosition: nil,
                releaseInfo: nil
            )
            
            let ffplay = ffmpeglib.Play()
            
            //音源開始
            let audioengine: FFAudioEngine = FFAudioEngine(play: ffplay)

//            ffplay.setAudio(bAudio: false)
//            ffplay.setVideo(bVideo: false)

            ffplay.setExtCallback( onexit: {
                return DispatchQueue.main.sync {
                    self.isplay
                }
            },onclock: { pos, clock, pause in
                DispatchQueue.main.async {
                    self.position = pos
                    guard !clock.isNaN else {
                        return
                    }
                    guard Int64(clock) < self.duration.components.seconds else {
                        return
                    }
                    self.now = .seconds(clock)
                }
            },upload_texture_cb: { width, height, format, pixelsPointer, pitch in

                let size = height * pitch
                let img = CGImage(
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bitsPerPixel: 32,
                    bytesPerRow: pitch,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo,
                    provider: CGDataProvider(
                        directInfo: UnsafeMutableRawPointer(mutating: pixelsPointer),
                        size: off_t(size),
                        callbacks: &callbacks)!,
                    decode: nil,
                    shouldInterpolate: false,
                    intent: .defaultIntent
                )
                
                DispatchQueue.main.async {
                    self.image = img
                }

            },oncontrol: { control, fargs in
                
                var result = false
                
                //pause
                let reqpause = DispatchQueue.main.sync {
                    if( self.reqpause ) {
                        self.reqpause = false
                        return true
                    }
                    return false
                }
                if( reqpause) {
                    control.advanced(by: 2).pointee = 1
                    result = true
                }

                var nowseek = 0.0
                let reqseek = DispatchQueue.main.sync {
                    if( self.reqseek ) {
                        self.reqseek = false
                        nowseek=self.nowseek
                        return true
                    }
                    return false
                }
                if(reqseek) {
                    control.pointee = 1
                    fargs.pointee = Float(nowseek)
                    result = true
                }
                return result
            },readyaudiodevice: { [audioengine ] channel,sample_rate in
                Task {
                    await audioengine.prepare(channels: channel, sampleRate: sample_rate)
                }
                return true
            },onstartaudio: {
                Task {
                    await audioengine.start()
                }
            },onstopaudio: {
                Task {
                    await audioengine.stop()
                }
            },update_subtile_cb: {
            })
            
            do {
                _ = ffplay.play(strfilename: filepath.path, vfilter: "", afilter: "")
                
                defer {
                    DispatchQueue.main.async {
                        self.image = nil
                    }
                    
                    Task {
                        await audioengine.dealloc()
                    }
                    
                    ffplay.end()
                    
                    DispatchQueue.main.sync {
                        self.isplay = false
                    }
                }
            }
        }
    }
}

///
/// ffplay画像ビュー
///
struct FFPlayImageView: View {

    @ObservedObject var vm: FFPlayImageViewModel
    
    var body: some View {
        ZStack {
            if vm.isplay == false {
                Color.black.overlay(
                    ProgressView().scaleEffect(1.5)
                )
            } else {
                
                if( vm.image == nil ) {
                    Color.red.overlay(
                        ProgressView().scaleEffect(1.5)
                    )
                } else {
                    Image(vm.image!, scale: 1.0, label: Text("Video"))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
        }
    }
}

