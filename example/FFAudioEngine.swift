//
//  FFAudioEngine.swift
//
//  Created by Takashi Nosaka on 2025/12/06.
//

import AVFAudio

import ffmpeglib

///
/// 音声エンジン
///
actor FFAudioEngine {
    
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
        
        lock.lock()
        defer {
            lock.unlock()
        }
        
        buffer1?.deallocate()
        buffer2?.deallocate()
    }
    
    ///
    /// デバイス準備
    ///
    func prepare( channels: Int, sampleRate: Int) {
        
        lock.lock()
        defer {
            lock.unlock()
        }
        
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
        guard !self.isFinished else {return}
        
        lock.lock()
        defer {
            lock.unlock()
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
            Task{
                await self.requestNextBuffer()
            }
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

        self.playerNode.stop()
    }
}
