//
//  ftbridge.swift
//  ffmpeglib
//
//  Created by Takashi Nosaka on 2026/03/27.
//

import UIKit

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
    private func end() {
        ftbridgewrap.Delete(self.wrapper)
    }

    /*
     * 画像生成
     */
    public func build(fontpath: String, fontsize: Int32, strvalue: String ) -> Bool {
        return wrapper.build(fontpath,fontsize,strvalue)
    }
    
    /*
     * フォント文字作成
     */
    public static func buildFontImage(_ fontfullpath: String,_ color:UIColor,_ size:Int, _ strvalue:String ) -> CGImage? {
        //フォント色構築
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let redU8   = UInt8(max(0, min(255, r * 255)))
        let greenU8 = UInt8(max(0, min(255, g * 255)))
        let blueU8  = UInt8(max(0, min(255, b * 255)))
        let alphaF  = Double(a)

        // 1パス目用の計測変数
        var minX: Double = 0, minY: Double = 0
        var maxX: Double = 0, maxY: Double = 0
        
        // フォント文字画像構築
        var canvasWidth = 0
        var canvasHeight = 0
        var rgbaBuffer:[UInt8]? = nil
        let bridge = ftbridge { loop, width, rows, pitch, pixels, cursor_x, cursor_y, x_offset, y_offset in
            let actualX = cursor_x + x_offset
            let actualY = cursor_y - y_offset // FreeTypeは上が正なので調整

            if loop == 0 {
                // --- 1パス目：バウンディングボックスの計算 ---
                minX = min(minX, actualX)
                minY = min(minY, actualY)
                maxX = max(maxX, actualX + Double(width))
                maxY = max(maxY, actualY + Double(rows))
            }
            if loop == 1 {
                if( canvasWidth == 0 && canvasHeight == 0 ) {
                    canvasWidth = Int(ceil(maxX - minX))
                    canvasHeight = Int(ceil(maxY - minY))
                    
                    // RGBAバッファの確保 (Width * Height * 4バイト)
                    rgbaBuffer = [UInt8](repeating: 0, count: canvasWidth * canvasHeight * 4)
                }
                guard canvasWidth > 0 && canvasHeight > 0 && rgbaBuffer != nil else { return }
                
                let actualX2 = Int(cursor_x + x_offset - minX)
                let actualY2 = Int(cursor_y - y_offset - minY)
                let src = pixels.assumingMemoryBound(to: UInt8.self)

                for row in 0..<rows {
                    for col in 0..<width {
                        let gray = src[row * pitch + col]
                        if gray == 0 { continue }

                        let destX = actualX2 + col
                        let destY = actualY2 + row + canvasHeight - rows
                        
                        if destX >= 0 && destX < canvasWidth && destY >= 0 && destY < canvasHeight {
                            let offset = (destY * canvasWidth + destX) * 4
                            // ユーザー指定の色をセット
                            rgbaBuffer![offset + 0] = redU8
                            rgbaBuffer![offset + 1] = greenU8
                            rgbaBuffer![offset + 2] = blueU8
                            // FreeTypeの輝度をアルファ（透明度）として使用
                            rgbaBuffer![offset + 3] = UInt8(Double(gray) * alphaF)
                        }
                    }
                }
            }
        }

        //構築処理
        _ = bridge.build(fontpath: fontfullpath, fontsize: Int32(size), strvalue: strvalue)
        
        defer {
            bridge.end()
        }

        guard canvasWidth > 0 && canvasHeight > 0 && rgbaBuffer != nil else { return nil}
        
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo: CGBitmapInfo = [
            .byteOrder32Big,
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        ]

        let size = canvasWidth * canvasHeight * 4
        let pixelData = Data(bytes: rgbaBuffer!, count: size)
        guard let provider = CGDataProvider(data: pixelData as CFData) else { return nil}
        
        return CGImage(
            width: canvasWidth,
            height: canvasHeight,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: canvasWidth*4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
    
}

