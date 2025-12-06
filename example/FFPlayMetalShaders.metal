//
//  Shaders.metal
//
//  Created by Takashi Nosaka on 2025/12/06.
//

#include <metal_stdlib>
using namespace metal;

struct ffplay_VertexOut {
    float4 position [[position]];
    float2 texcoord;
};

vertex ffplay_VertexOut ffplay_vertex_passthrough(uint vertexID [[vertex_id]]) {
    ffplay_VertexOut out;

    // フルスクリーン三角ストリップ順序（0..3）
    float2 positions[4] = {
        float2(-1.0, -1.0), // 左下
        float2( 1.0, -1.0), // 右下
        float2(-1.0,  1.0), // 左上
        float2( 1.0,  1.0)  // 右上
    };

    float2 uvs[4] = {
        float2(0.0, 1.0), // 注意: Metal のテクスチャ縦方向は通常 0=上, 1=下 ではないので、手元のデータに合わせて調整
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0)
    };

    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texcoord = uvs[vertexID];
    return out;
}

fragment float4 ffplay_fragment_texture(ffplay_VertexOut in [[stage_in]],
                                 texture2d<half, access::sample> tex [[texture(0)]],
                                 sampler samp [[sampler(0)]]) {
    // sampler は linear にしてあるので縮小時に補間される
    half4 c = tex.sample(samp, in.texcoord);
    return float4(c);
}
