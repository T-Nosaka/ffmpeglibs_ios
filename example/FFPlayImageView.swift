//
//  FFPlayImageView.swift
//
//  Created by Takashi Nosaka on 2025/11/30.
//

import SwiftUI
import Combine
import AVFAudio

import ffmpeglib

///
/// 音声エンジン
///
actor AudioEngine {
    
    private var ffplay: ffmpeglib.Play
    //ダブルバッファ
    private var buffer1:UnsafeMutableBufferPointer<UInt8>?
    private var buffer2:UnsafeMutableBufferPointer<UInt8>?

    //バッファサイズ
    private var buffersize:Int32 = 0
    
    //バッファフレーム数
    private var frameCount:Int32 = 0
    
    //バッファ識別
    private var currentBuffer = 1  // 1→buffer2, 2→buffer1

    //完了フラグ
    private var isFinished = false

    private let lock = NSLock()
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioFormat: AVAudioFormat!
    
    ///
    /// コンストラクタ
    ///
    public init(play:ffmpeglib.Play) {
        self.ffplay = play
    }
    
    ///
    /// リソース破棄
    ///
    func dealloc() {
        buffer1?.deallocate()
        buffer2?.deallocate()
    }
    
    ///
    /// デバイス準備
    ///
    func prepare( channels: Int, sampleRate: Int) {
        
        audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                    sampleRate: Double(sampleRate),
                                    channels: AVAudioChannelCount(channels),
                                    interleaved: false)!

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: audioFormat)
        try? engine.start()

        //最小のバッファサイズ
        self.buffersize = Int32(sampleRate * 2 * channels)/100
        buffer1 = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: Int(self.buffersize))
        buffer2 = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: Int(self.buffersize))
        
        self.frameCount = buffersize/Int32(audioFormat.channelCount)/2

    }

    ///
    /// 再生開始
    ///
    func start() {
        //ダブルリングバッファ
        self.requestNextBuffer()
        self.requestNextBuffer()

        playerNode.play()
    }
    
    ///
    /// 次回バッファ要求
    ///
    private func requestNextBuffer() {
        lock.lock()
        defer {
            lock.unlock()
        }
        
        if( self.isFinished ) {
            return
        }
        
        let targetBuffer = currentBuffer == 1 ? buffer1! : buffer2!
        ffplay.audiocallback(audiobuffer: UnsafeMutableRawPointer(targetBuffer.baseAddress!), len: self.buffersize);
        scheduleAudioBuffer(targetBuffer)
        currentBuffer = currentBuffer == 1 ? 2 : 1
    }

    ///
    /// サンプリングバッファセット
    ///
    private func scheduleAudioBuffer(_ buffer: UnsafeMutableBufferPointer<UInt8>) {
        // UInt8 → Int16 にキャスト
        let int16Pointer = buffer.baseAddress!.withMemoryRebound(to: Int16.self, capacity: Int(buffersize) / 2) { pointer in
                return pointer
            }
        
        // AVAudioPCMBuffer 作成
        let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount))!
        audioBuffer.frameLength = audioBuffer.frameCapacity

        // Int16データをAVAudioPCMBufferにコピー
        if let channelData = audioBuffer.int16ChannelData {
            if audioFormat.channelCount == 1 {
                // 1Channel
                memcpy(channelData[0], int16Pointer, Int(buffersize))
            } else if audioFormat.channelCount == 2 {
                // MultiChannel Interleave
                for ch in 0..<Int(audioFormat.channelCount) {
                    for iPos in 0..<Int(frameCount) {
                        channelData[ch][iPos] = int16Pointer[iPos*2+ch]
                    }
                }
            }
        }

        // サンプリングバッファセット
        playerNode.scheduleBuffer(audioBuffer) { [self] in
            self.requestNextBuffer()
        }
    }
   
    ///
    /// 停止
    ///
    func stop() {
        lock.lock()
        defer {
            lock.unlock()
        }
        isFinished = true

        playerNode.stop()
    }
}



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

        _ = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            let ffplay = ffmpeglib.Play()

            //音源開始
            let audioengine: AudioEngine = AudioEngine(play: ffplay)

//            ffplay.setAudio(bAudio: false)
//            ffplay.setVideo(bVideo: false)

            ffplay.setExtCallback( onexit: {
                let isplay = DispatchQueue.main.sync {
                    self.isplay
                }
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
                DispatchQueue.main.sync {
                    
                    //                            control.pointee = 1
                    //                            control.advanced(by: 1).pointee = 2
                    
                    //                            fargs.pointee = 3.14159
                }
                    
                return false
            },readyaudiodevice: { [audioengine ] channel,sample_rate in
                
                DispatchQueue.main.async {
                    audioengine.prepare(channels: channel, sampleRate: sample_rate)
                }
                
                return true
            },onstartaudio: {
                DispatchQueue.main.async {
                    audioengine.start()
                }
            },onstopaudio: {
                DispatchQueue.main.async {
                    audioengine.stop()
                }
            },update_subtile_cb: {
            })
            
            _ = ffplay.play(strfilename: filepath.path, vfilter: "", afilter: "")
            
            await audioengine.dealloc()
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

