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

