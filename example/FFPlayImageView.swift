//
//  FFPlayImageView.swift
//  example
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
    
    //
    // 映像
    //
    @Published var image : CGImage? = nil
    
    ///
    /// 再生
    ///
    func play( filepath: URL ) {
        
        if( isplay == true ) {
            isplay = false
        }
        
        isplay = true

        _ = Task.detached(priority: .userInitiated) { [weak self, isplay] in
            
            guard let self = self else { return }

            let ffplay = ffmpeglib.Play()
            
            ffplay.setAudio(bAudio: false)
//            ffplay.setVideo(bVideo: false)

            ffplay.setExtCallback( onexit: {
                return isplay
            },onclock: { pos, clock, pause in
                
                print( "\(pos),\(clock)" )
                
            },upload_texture_cb: { width, height, format, pixelsPointer, pitch in

                let colorSpace = CGColorSpaceCreateDeviceRGB()
                let bitmapInfo: CGBitmapInfo = [
                    .byteOrder32Little,
                    CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
                ]
                
                let dataProvider = CGDataProvider(
                    dataInfo: nil,
                    data: pixelsPointer,
                    size: pitch * height,
                    releaseData: { _, _, _ in }
                )
                
                let img = CGImage(
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bitsPerPixel: 32,
                    bytesPerRow: pitch,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo,
                    provider: dataProvider!,
                    decode: nil,
                    shouldInterpolate: false,
                    intent: .defaultIntent
                )
                
                Task { @MainActor in
                    self.image = img
                }
                
            },oncontrol: { control, fargs in
    //                            control.pointee = 1
    //                            control.advanced(by: 1).pointee = 2
                
    //                            fargs.pointee = 3.14159

                return false
            },readyaudiodevice: { channel,sample_rate in
                return true
            },onstartaudio: {
            },onstopaudio: {
            },update_subtile_cb: {
            })
            
            _ = ffplay.play(strfilename: filepath.path, vfilter: "", afilter: "")
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

