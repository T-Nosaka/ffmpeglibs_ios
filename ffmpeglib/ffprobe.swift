//
//  ffprobe.swift
//  ffmpeglib
//
//  Created by Takashi Nosaka on 2025/12/14.
//

import Foundation

/*
 * probe media file
 */
public class ffprobe {
    public var format = "unknown"
    public var duration = 0.0
    public var streams : [streaminfo] = []
    public var metadata: [String: String]?
    
    public class streaminfo {
        public var id: Int = 0
        public var type = AVMediaType.unknown
        public var codecid = AVCodecID.none
        public var width: Int = 0
        public var height: Int = 0
        public var channels: Int = 0
        public var sample_rate: Int = 0
        public var codec_tag: Int = 0
        public var rotation: Double? = nil
        public var framerate: Double? = nil
    }
    
    public init () {
    }
    
    //
    // probe
    //
    public func probe(_ filepath: URL ) throws {
        let mediainfo = try ffmpeglib.Convert.parse(filepath: filepath.path)
        
        if( mediainfo["format"] != nil ) {
            self.format = mediainfo["format"] as! String
        }
        if( mediainfo["duration"] != nil ) {
            self.duration = mediainfo["duration"] as? Double ?? 0.0
        }
        if( mediainfo["metadata"] != nil ) {
            self.metadata = mediainfo["metadata"] as? [String: String]
        }
        
        if( mediainfo["streams"] != nil ) {
            let streams = mediainfo["streams"] as! [[String: Any]]
            for stream in streams {
                let streaminfo = streaminfo()
                streaminfo.id = stream["id"] as! Int
                streaminfo.codecid = AVCodecID.valueOf(stream["codecid"] as! Int)
                streaminfo.type = AVMediaType.valueOf(stream["type"] as! Int)
                if( streaminfo.type == ffmpeglib.AVMediaType.video ) {
                    streaminfo.width = stream["width"] as! Int
                    streaminfo.height = stream["height"] as! Int
                    streaminfo.rotation = stream["rotation"] as? Double
                    streaminfo.framerate = stream["frame_rate"] as? Double
                }
                if( streaminfo.type == ffmpeglib.AVMediaType.audio ) {
                    streaminfo.channels = stream["channels"] as! Int
                    streaminfo.sample_rate = stream["sample_rate"] as! Int
                }
                
                self.streams.append(streaminfo)
            }
        }
    }
}
