//
//  TimeTrackSlider.swift
//
//  Created by Takashi Nosaka on 2025/12/08.
//

import Foundation
import SwiftUI
import Combine

///
/// タイムラインスライダモデル
///
class TimeTruckModel: ObservableObject {

    ///
    /// 再生位置 (秒)
    ///
    @Published var value: Float {
        didSet {
            if( value < valueRange.lowerBound ) {
                value = valueRange.lowerBound
            } else if( value > valueRange.upperBound ) {
                value = valueRange.upperBound
            }
        }
    }
    
    ///
    /// 拡大率
    ///
    @Published var scale: Float = 1.0
    
    ///
    /// ドラッグ中判定
    ///
    @Published var isDragging: Bool = false
    
    ///
    /// 時間範囲 (秒)
    ///
    @Published var valueRange: ClosedRange<Float> = 0.0...0.0
    
    ///
    /// スケール範囲
    ///
    var scaleRange: ClosedRange<Float> = 0.01...20.0
    
    ///
    /// View幅 設定
    ///
    var boxWidthPx: Float = 0.0 {
        didSet {
            // boxWidthPxが設定されたら、適切な初期スケールを計算する
            if boxWidthPx > 0 {
                // 初期スケールを、全幅の1/3が表示される程度に調整
                let totalDuration = valueRange.upperBound - valueRange.lowerBound
                let initialScale = (boxWidthPx ) / totalDuration
                //値域修正
                scale = max(scaleRange.lowerBound, min(initialScale, scaleRange.upperBound))
            }
        }
    }
    
    ///
    /// ドラッグ開始位置
    ///
    private var startDragValue: Float = 0.0
    
    ///
    /// ピンチジェスチャー開始時の状態
    ///
    var startPinchScale: Float?

    ///
    /// コンストラクタ
    ///
    init(initialValue: Float, range: ClosedRange<Float> ) {
        self.value = initialValue
        self.valueRange = range
    }
    
    ///
    /// タイムラインドラッグ開始
    ///
    func handlePanStart(translation: CGPoint) {
        //translation ドラッグ開始絶対位置
        
        self.isDragging = true
        self.startDragValue = self.value
    }
    
    ///
    /// タイムラインドラッグ中
    ///
    func handlePanChanged(translation: CGSize) {
        guard boxWidthPx > 0 else { return }
        //translation ドラッグ開始からの相対位置
        
        // ドラッグ開始からの距離で差分量を産出
        let deltaValue = Float(-translation.width) / self.scale
        
        // 新しい値を計算し、範囲内にクランプ
        let newValue = (self.startDragValue + deltaValue)
        
        // 状態を更新
        self.value = newValue
    }
    
    ///
    /// タイムラインドラッグ完了
    ///
    func handlePanEnd() {
        self.isDragging = false
    }
    
    ///
    /// タイムラインのズーム開始
    ///
    func handleZoomStart() {
        self.startPinchScale = self.scale
    }
    
    ///
    /// タイムラインのズーム中
    ///
    func handleZoomChanged(magnification: CGFloat) {
        let startScale = self.startPinchScale!
        
        // 新しいスケールを計算
        let newScale = startScale * Float(magnification)
        
        //値域修正
        self.scale = max(scaleRange.lowerBound, min(newScale, scaleRange.upperBound))
    }
    
    ///
    /// タイムラインのズーム終了
    ///
    func handleZoomEnd() {
        self.startPinchScale = nil
    }
}

///
/// タイムラインスライダビュー
///
struct TimeTruckSliderView: View {
    
    @StateObject var model: TimeTruckModel
    
    // カスタム描画に使う定数
    let trackHeight: CGFloat = 3.0 // DPに対応
    let lineThickness: CGFloat = 3.0 // DPに対応
    let heightMag: CGFloat = 10.0 // 全体の高さ倍率
    let topMargin: Float = 0.0 // 上マージン
    
    var body: some View {
        // 全幅を取り、自身のサイズを取得するためにGeometryReaderを使用
        GeometryReader { geometry in
            
            let boxWidthPx = geometry.size.width
            let boxHeightPx = geometry.size.height
            
            // サイズをモデルに伝達
            Color.clear
                .onAppear {
                    model.boxWidthPx = Float(boxWidthPx)
                }
            
            // 描画ロジックをCanvas内に記述
            Canvas { context, size in
                // モデルが初期化され、幅が取得されていることを確認
                guard model.boxWidthPx > 0 else { return }
                
                let centerX = Float(size.width * 0.5)
                let centerY = Float(size.height * 0.5) + topMargin
                let centerYtoB = Float(size.height) - centerY // 下端までの距離

                // 再生位置に応じてトラックを移動させるためのオフセットを計算
                let offsetPx = model.value * model.scale
                let trackStartX = centerX - model.valueRange.lowerBound * model.scale - offsetPx
                let trackEndX = centerX + model.valueRange.upperBound * model.scale - offsetPx

                // 水平トラック背景線
                var path = Path()
                path.move(to: CGPoint(x: max(0.0, Double(trackStartX)), y: Double(centerY)))
                path.addLine(to: CGPoint(x: min(boxWidthPx, CGFloat(trackEndX)), y: CGFloat(centerY)))
                
                context.stroke(path, with: .color(Color(uiColor: .systemGray5)), lineWidth: trackHeight)
                
                // 目盛りの描画
                drawTimeMarkers(
                    context: context,
                    size: size,
                    centerX: CGFloat(centerX),
                    centerY: CGFloat(centerY),
                    centerYtoB: CGFloat(centerYtoB)
                )

                // 再生位置カーソル線
                var centerPath = Path()
                centerPath.move(to: CGPoint(x: Int(centerX), y: Int(topMargin)))
                centerPath.addLine(to: CGPoint(x: Int(centerX), y: Int(boxHeightPx)))
                
                context.stroke(centerPath, with: .color(model.isDragging ? .orange : .blue), lineWidth: lineThickness)
                
            }
            // 描画領域の背景色（必要に応じて）
            .background(Color(uiColor: .systemBackground))
            .frame(height: boxHeightPx)
            
            // ジェスチャーの適用
            .gesture(panGesture) // 1本指での移動
            .gesture(zoomGesture) // 2本指でのズーム
            
        }
        // コンポーネントの高さ設定
        .frame(height: trackHeight * heightMag + CGFloat(topMargin))
    }
   
    ///
    /// 目盛り線
    ///
    private func drawTimeMarkers(
        context: GraphicsContext,
        size: CGSize,
        centerX: CGFloat,
        centerY: CGFloat,
        centerYtoB: CGFloat
    ) {
        let boxWidthPx = size.width
        let currentScale = model.scale
        let currentValue = model.value
        let lineThicknessPx = lineThickness
        let seclineThicknessPx = lineThickness * 0.3
        
        let markerColor = Color(uiColor: .systemGray)
        
        // 分/10分単位の目盛り (長い目盛り)
        var lstep: Int = 60 // 1分
        if currentScale < 0.4 {
            lstep = 60 * 10 // 10分
        }
        
        for axes in stride(from: Int(model.valueRange.lowerBound), to: Int(model.valueRange.upperBound), by: lstep) {
            
            // X座標を計算 (Composeロジックを移植)
            var pos = centerX - (CGFloat(model.valueRange.lowerBound - Float(axes)) * CGFloat(currentScale))
            pos -= CGFloat(currentValue * currentScale)
            
            if pos < 0 || pos > boxWidthPx { continue }
            
            var markerPath = Path()
            markerPath.move(to: CGPoint(x: pos, y: centerY))
            markerPath.addLine(to: CGPoint(x: pos, y: centerY + centerYtoB * 0.25)) // 25%の長さ
            
            context.stroke(markerPath, with: .color(markerColor), lineWidth: lineThicknessPx)
        }
        
        // 1秒単位の目盛り (短い目盛り) - ズームイン時のみ表示
        if currentScale > 6.0 {
            let secTopY = centerY - centerYtoB * 0.25
            
            for axes in stride(from: Int(model.valueRange.lowerBound), to: Int(model.valueRange.upperBound) + 1, by: 1) {
                
                // X座標を計算
                var pos = centerX - (CGFloat(model.valueRange.lowerBound - Float(axes)) * CGFloat(currentScale))
                pos -= CGFloat(currentValue * currentScale)
                
                if pos < 0 || pos > boxWidthPx { continue }
                
                var markerPath = Path()
                markerPath.move(to: CGPoint(x: pos, y: centerY))
                markerPath.addLine(to: CGPoint(x: pos, y: secTopY)) // 上方向に短い線
                
                context.stroke(markerPath, with: .color(markerColor), lineWidth: seclineThicknessPx)
            }
        }
    }
    
    ///
    /// ドラッグジェスチャー
    ///
    var panGesture: some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .local)
            .onChanged { value in
                // ドラッグ開始をモデルに通知（開始時のみ）
                if !model.isDragging {
                    model.handlePanStart(translation: value.startLocation)
                }
                model.handlePanChanged(translation: value.translation)
            }
            .onEnded { _ in
                model.handlePanEnd()
            }
    }
    
    ///
    /// ズームジェスチャー
    ///
    var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                // ズーム開始をモデルに通知（開始時のみ）
                if model.startPinchScale == nil {
                    model.handleZoomStart()
                }
                model.handleZoomChanged(magnification: value.magnification)
            }
            .onEnded { _ in
                model.handleZoomEnd()
            }
    }
}
