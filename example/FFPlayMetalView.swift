//
//  FFPlayMetalView.swift
//
//  Created by Takashi Nosaka on 2025/11/30.
//

import SwiftUI
import Combine
import MetalKit

import ffmpeglib

///
/// ffplay画像モデル
///
class FFPlayMetalViewModel: ObservableObject {

    ///
    /// ビューワ保持
    ///
    weak var renderCoordinator: FFPlayMetalView.Coordinator?
    
    //
    // 再生状態と制御
    //
    @Published var isplay : Bool = false
    @Published var reqpause : Bool = false
    // シーク要求
    private var reqseek : Bool = false
    private var nowseek:Double = 0.0
    
    //
    // メディア情報
    //
    @Published var format = "unknown"
    @Published var duration = Duration(attoseconds: 0)
    @Published var width = 0
    @Published var height = 0

    //
    // 現在値
    //
    @Published var position:Double = 0.0
    @Published var now:Duration = .seconds(0)

    //
    // メディア情報取得
    //
    func probe(_ filepath: URL ) {
        let fp = ffmpeglib.ffprobe()
        fp.probe(filepath)
        
        format = fp.format
        duration = .seconds( fp.duration )

        var vfind = false
        for stream in fp.streams {
            if ( vfind == false && stream.type == .video) {
                if( stream.rotation == nil ) {
                    self.width = stream.width
                    self.height = stream.height
                } else {
                    if( Int(stream.rotation!) == 90 || Int(stream.rotation!) == -90 ) {
                        self.width = stream.height
                        self.height = stream.width
                    } else {
                        self.width = stream.width
                        self.height = stream.height
                    }
                }
                
                vfind = true
            }
        }
    }

    //
    // シーク要求
    //
    func reqseek(_ nowtime:Double ) {
        nowseek = nowtime
        reqseek = true
    }
    
    ///
    /// 映像記録
    ///
    private func setPixel( _ pixels: Data?, _ width: Int, _ height: Int, _ pitch: Int ) {
        if let coordinator = self.renderCoordinator,
               let data = pixels {
                // Dataから読み取り専用のポインタを一時的に取り出し、uploadに渡す
                data.withUnsafeBytes { rawBufferPointer in
                    if let rawPtr = rawBufferPointer.baseAddress {
                        coordinator.upload(pixels: rawPtr, width: width, height: height, pitch: pitch)
                    }
                }
            }
    }
    
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
            
            await self.probe( filepath )
            
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
            },upload_texture_cb: {  width, height, format, pixelsPointer, pitch in
                let size = height * pitch
                let pixelData = Data(bytes: pixelsPointer, count: size)
                Task { @MainActor in
                    self.setPixel(pixelData, width, height, pitch)
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

//
// FFPLAY描画ビュー
//
struct FFPlayMetalView: UIViewRepresentable {
    
    ///
    /// モデル
    ///
    @ObservedObject var vm: FFPlayMetalViewModel

    ///
    /// MTKViewビュー構築
    ///
    func makeUIView(context: Context) -> MTKView {
        let mtk = MTKView()
        mtk.device = MTLCreateSystemDefaultDevice()
        mtk.isPaused = true
        mtk.enableSetNeedsDisplay = true
        mtk.delegate = context.coordinator
        
        //相互保持
        context.coordinator.mtkView = mtk
        
        return mtk
    }

    ///
    /// 画素更新
    ///
    func updateUIView(_ uiView: MTKView, context: Context) {
    }

    ///
    /// 画素を渡すコーディネータ構築
    ///
    func makeCoordinator() -> Coordinator {
            let coordinator = Coordinator()
            // ここで ViewModelに Coordinatorの参照をセットする
            vm.renderCoordinator = coordinator
            return coordinator
        }
    
    ///
    /// コーディネータ構築
    ///
    class Coordinator: NSObject, MTKViewDelegate {
        weak var mtkView: MTKView?

        // 画素テクスチャ（ソース）
        var texture: MTLTexture?

        // Metal オブジェクト
        private var device: MTLDevice!
        private var commandQueue: MTLCommandQueue!
        private var pipelineState: MTLRenderPipelineState!
        private var samplerState: MTLSamplerState!

        override init() {
            super.init()
            // device は makeUIView からセットされるが、念のため nil チェックは行う
        }

        ///
        /// MTLDevice設定
        ///
        func setupIfNeeded(for view: MTKView) {
            guard let dev = view.device else { return }
            if device == nil {
                device = dev
                commandQueue = device.makeCommandQueue()
                makePipeline(device: device, view: view)
                makeSampler(device: device)
            }
        }

        ///
        /// サンプラー構築
        ///
        private func makeSampler(device: MTLDevice) {
            //bylinerで拡縮
            let desc = MTLSamplerDescriptor()
            desc.minFilter = .linear
            desc.magFilter = .linear
            desc.sAddressMode = .clampToEdge
            desc.tAddressMode = .clampToEdge
            samplerState = device.makeSamplerState(descriptor: desc)
        }

        ///
        /// GPUパイプライン構築
        ///
        private func makePipeline(device: MTLDevice, view: MTKView) {
            // デフォルトライブラリに .metal ファイルを入れておく（下にシェーダー例あり）
            guard let library = device.makeDefaultLibrary() else {
                fatalError("Default library not found. Add .metal file to target.")
            }
            guard let vfunc = library.makeFunction(name: "ffplay_vertex_passthrough"),
                  let ffunc = library.makeFunction(name: "ffplay_fragment_texture") else {
                fatalError("Shader functions not found in library")
            }

            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vfunc
            desc.fragmentFunction = ffunc
            desc.colorAttachments[0].pixelFormat = view.colorPixelFormat // 通常 .bgra8Unorm
            do {
                pipelineState = try device.makeRenderPipelineState(descriptor: desc)
            } catch {
                fatalError("Failed to create pipeline state: \(error)")
            }
        }

        ///
        /// 画素をテクスチャに転送
        ///
        func upload(pixels: UnsafeRawPointer, width: Int, height: Int, pitch: Int ) {
            guard let mtkView = mtkView,
                  let device = mtkView.device else { return }

            // テクスチャ再利用（サイズが変わったら再作成）
            if texture == nil || texture!.width != width || texture!.height != height {
                let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: .bgra8Unorm,
                    width: width,
                    height: height,
                    mipmapped: false)
                descriptor.usage = [.shaderRead]
                descriptor.storageMode = .shared
                texture = device.makeTexture(descriptor: descriptor)
            }

            guard let texture = texture else { return }

            let region = MTLRegionMake2D(0, 0, width, height)
            texture.replace(region: region, mipmapLevel: 0, withBytes: pixels, bytesPerRow: pitch)

            // 描画依頼
            self.mtkView?.setNeedsDisplay()
        }

        ///
        /// 描画
        ///
        func draw(in view: MTKView) {
            setupIfNeeded(for: view)

            guard let texture = texture,
                  let drawable = view.currentDrawable,
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let pipelineState = pipelineState else { return }

            // RenderPass 設定
            let renderPassDesc = MTLRenderPassDescriptor()
            renderPassDesc.colorAttachments[0].texture = drawable.texture
            renderPassDesc.colorAttachments[0].loadAction = .clear
            renderPassDesc.colorAttachments[0].storeAction = .store
            renderPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)

            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc) else { return }
            encoder.setRenderPipelineState(pipelineState)

            // テクスチャをフラグメントにセット
            encoder.setFragmentTexture(texture, index: 0)

            // サンプラー
            if let sampler = samplerState {
                encoder.setFragmentSamplerState(sampler, index: 0)
            }

            // ビューポート（省略可能：デフォルトで描画先全体）
            let drawableSize = view.drawableSize
            encoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(drawableSize.width), height: Double(drawableSize.height), znear: 0.0, zfar: 1.0))

            // フルスクリーン四角形を三角ストリップで描画（vertex shader が座標とUVを決める）
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // 必要ならここで処理（例: アスペクト比計算等）
        }
    }
}
