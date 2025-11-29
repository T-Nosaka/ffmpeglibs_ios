//
//  ffmpeglib.swift
//  ffmpeglib
//
//  Created by Takashi Nosaka on 2025/11/19.
//

import Foundation

//
// define callback
//
typealias RunCallback = @convention(c) (
    UnsafeMutableRawPointer?,
    Int32,                      // is_last_report (0=途中, 1=終了)
    Int64,                      // timer_start
    Int64,                      // cur_time
    Int64                       // pts
) -> Int32

//
// Convert FFMPEG
//
public class Convert {
    
    //
    // Callback Progress
    //
    private let progresscallback: RunCallback = { pext, isLast, start, cur, pts in
        if let pext {
            // call self
            let obj = Unmanaged<Convert>.fromOpaque(pext).takeUnretainedValue()
            if( obj.gocallback != nil ) {
                let rtn = obj.gocallback!( start, cur, pts )
                return rtn==true ? 0 : 1
            }
        }
        return 0
    }
    
    //
    // func go instance callback
    //
    private var gocallback: (( Int64, Int64, Int64 ) -> Bool)? = nil
    
    //
    // go
    //
    public func go( args: [String], prgcallback:  @escaping ( Int64, Int64, Int64 ) -> Bool ) -> Int32 {

        var cArgs = args.map { strdup($0) }
        defer {
            for ptr in cArgs { free(ptr) }
        }
        
        self.gocallback = prgcallback
        
        let ext = self
        let extPtr = Unmanaged.passUnretained(ext).toOpaque()

        let result = run(
                Int32(args.count),
                &cArgs,
                extPtr,
                progresscallback
            )
        
        return result
    }

    //
    // Construct
    //
    public init() {
    }
    
    //
    // Destruct
    //
    deinit {
    }

}

//
// FFMpeg play
//
public class Play {
    
    private let wrapper: ffplayobjwrap = ffplayobjwrap()
    
    //
    // Construct
    //
    public init() {
    }
    
    //
    // Destruct
    //
    deinit {
        ffplayobjwrap.Delete(wrapper)
    }

    public func setAudio( bAudio: Bool ) {
        wrapper.setAudio(bAudio)
    }
    public func setVideo( bVideo: Bool ) {
        wrapper.setVideo(bVideo)
    }
    public func setSubTitle( bSubtitle: Bool ) {
        wrapper.setSubTitle(bSubtitle)
    }
    public func setAutoexit( bAutoexit: Bool ) {
        wrapper.setAutoexit(bAutoexit)
    }
    
    public func audiocallback(stream:Data, len:Int32) {
        var mutableStream = stream
        mutableStream.withUnsafeMutableBytes { rawBuffer in
            let ptr = rawBuffer.bindMemory(to: UInt8.self).baseAddress!
            wrapper.audiocallback(ptr, len)
        }
    }
    
    // Define callback function
    private var FFPlay_onExit: (()->Bool)? = nil
    private var FFPlay_onClock: ((Double,Double,Int32)->Void)? = nil
    private var FFPlay_UploadTextureCb: ((Int,Int,Int,[UInt8],Int)->Void)? = nil
    private var FFPlay_onControl: ((UnsafeMutablePointer<Int64>,UnsafeMutablePointer<Float>)->Bool)? = nil
    private var FFPlay_ReadyAudiodevice: ((Int,Int)->Bool)? = nil
    private var FFPlay_OnStartAudio: (()->Void)? = nil
    private var FFPlay_OnStopAudio: (()->Void)? = nil
    private var FFPlay_UpdateSubtitleCb: (()->Void)? = nil

    //
    // set Extra Callback
    //
    public func setExtCallback(
        onexit:@escaping ()->Bool,
        onclock:@escaping (_ pos:Double,_ clock:Double,_ pause:Int32)->Void,
        upload_texture_cb:@escaping (_ width:Int,_ height:Int,_ format:Int,_ pixels:[UInt8],_ pitch:Int)->Void,
        oncontrol:@escaping (_ control: UnsafeMutablePointer<Int64>,_ fargs:UnsafeMutablePointer<Float>)->Bool,
        readyaudiodevice:@escaping (_ channel:Int, _ sample_rate:Int)->Bool,
        onstartaudio:@escaping ()->Void,
        onstopaudio:@escaping ()->Void,
        update_subtile_cb:@escaping ()->Void
    ) {
        self.FFPlay_onExit = onexit
        self.FFPlay_onClock = onclock
        self.FFPlay_UploadTextureCb = upload_texture_cb
        self.FFPlay_onControl = oncontrol
        self.FFPlay_ReadyAudiodevice = readyaudiodevice
        self.FFPlay_OnStartAudio = onstartaudio
        self.FFPlay_OnStopAudio = onstopaudio
        self.FFPlay_UpdateSubtitleCb = update_subtile_cb

        wrapper.setExtCallback( Unmanaged.passUnretained(self).toOpaque(),
            { contextPointer in
                return Unmanaged<Play>.fromOpaque(contextPointer!).takeUnretainedValue().FFPlay_onExit?() ?? false
            },
            { contextPointer, pos, clock, pause in
                Unmanaged<Play>.fromOpaque(contextPointer!).takeUnretainedValue().FFPlay_onClock?( pos, clock, pause )
            },
            { contextPointer , width, height, format, pixelsPointer, pitch in
                let numPixels:Int = Int(width * height)
                var pixelArray:[UInt8] = []
                pixelsPointer!.withMemoryRebound(to: UInt8.self, capacity: numPixels) { typedPointer in
                    // build swift UInt8 array
                    pixelArray = Array(UnsafeBufferPointer(start: typedPointer, count: numPixels))
                }
                Unmanaged<Play>.fromOpaque(contextPointer!).takeUnretainedValue().FFPlay_UploadTextureCb?(Int(width), Int(height), Int(format), pixelArray, Int(pitch))
            },
            { contextPointer, control, fargs in
                return Unmanaged<Play>.fromOpaque(contextPointer!).takeUnretainedValue().FFPlay_onControl?( control!, fargs! ) ?? false
            },
            { contextPointer,channel,sample_rate in
                return Unmanaged<Play>.fromOpaque(contextPointer!).takeUnretainedValue().FFPlay_ReadyAudiodevice?( Int(channel), Int(sample_rate) ) ?? false
            },
            { contextPointer in
                Unmanaged<Play>.fromOpaque(contextPointer!).takeUnretainedValue().FFPlay_OnStartAudio?()
            },
            { contextPointer in
                Unmanaged<Play>.fromOpaque(contextPointer!).takeUnretainedValue().FFPlay_OnStopAudio?()
            },
            { contextPointer in
                Unmanaged<Play>.fromOpaque(contextPointer!).takeUnretainedValue().FFPlay_UpdateSubtitleCb?()
            }
        )
    }
}

