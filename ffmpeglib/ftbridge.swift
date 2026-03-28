//
//  ftbridge.swift
//  ffmpeglib
//
//  Created by Takashi Nosaka on 2026/03/27.
//

import Foundation

/*
 * FreeTypeラッパ
 */
public class ftbridge {
    
    private let wrapper: ftbridgewrap = ftbridgewrap()

    /*
     * 描画コールバック
     */
    private var ftbridge_rendercb: ((Int,Int,Int,Int,UnsafeRawPointer,Double,Double,Double,Double)->Void)? = nil
    
    //
    // Construct
    //
    public init( rendercb:@escaping (_ loop:Int ,_ width:Int,_ rows:Int,_ pitch:Int,_ pixels:UnsafeRawPointer,_ cursor_x:Double,_ cursor_y:Double, _ x_offset:Double,_ y_offset:Double)->Void ) {
        //コールバック設置
        self.ftbridge_rendercb = rendercb
        self.wrapper.setRenderCallback( Unmanaged.passUnretained(self).toOpaque()) { contextPointer , loop, width, rows, pitch, pixelsPointer, cursor_x, cursor_y, x_offset, y_offset in
            guard pixelsPointer != nil else { return }
            Unmanaged<ftbridge>.fromOpaque(contextPointer!).takeUnretainedValue().ftbridge_rendercb?(Int(loop), Int(width), Int(rows), Int(pitch), pixelsPointer!, Double(cursor_x), Double(cursor_y), Double(x_offset), Double(y_offset))
        }
    }
    
    deinit {
    }

    //
    // 破棄処理
    //
    public func end() {
        ftbridgewrap.Delete(self.wrapper)
    }

    /*
     * 画像生成
     */
    public func build(fontpath: String, fontsize: Int32, strvalue: String ) -> Bool {
        return wrapper.build(fontpath,fontsize,strvalue)
    }
}

