#include <iostream>
extern "C" {
#include <ft2build.h>
#include FT_FREETYPE_H
#include <hb.h>
#include <hb-ft.h>
}

#include "usingblock.h"
#include "ftbridge.hpp"



bool ftbridgewrap::build(const char* fontpath, int fontsize, const char* strvalue ) {
    
    FT_Error error;
    
    FT_Library ft_library;
    error = FT_Init_FreeType(&ft_library);
    if (error)
        return false;
    
    auto ft_library_block = UsingBlock( [ft_library](void *_) {
        FT_Done_FreeType(ft_library);
    } );
    
    
    FT_Face face;
    error = FT_New_Face(ft_library, fontpath, 0, &face);
    if (error)
        return false;

    auto face_block = UsingBlock( [face](void *_) {
        FT_Done_Face(face);
    } );
    
    //Pixel サイズ指定
    FT_Set_Pixel_Sizes(face, 0, fontsize);

    //HarfBuzzフォントオブジェクト作成
    hb_font_t *hb_font = hb_ft_font_create(face, NULL);
    auto hb_font_block = UsingBlock( [hb_font](void *_) {
        hb_font_destroy(hb_font);
    } );
    
    //HarfBuzz バッファに文字列をセット
    hb_buffer_t *buf = hb_buffer_create();
    auto buf_block = UsingBlock( [buf](void *_) {
        hb_buffer_destroy(buf);
    } );
    
    hb_buffer_add_utf8(buf, strvalue, -1, 0, -1);
    
    //テキスト解析推測
    hb_buffer_guess_segment_properties(buf);

    //シェイピング実行
    hb_shape(hb_font, buf, NULL, 0);
    
    //結果（グリフIDと座標）取得
    unsigned int glyph_count;
    hb_glyph_info_t *glyph_info = hb_buffer_get_glyph_infos(buf, &glyph_count);
    hb_glyph_position_t *glyph_pos = hb_buffer_get_glyph_positions(buf, &glyph_count);

    // 描画ループ(解析,描画)
    for( int i=0; i<2; i++ ) {
        double cursor_x = 0;
        double cursor_y = 0;
        
        for (unsigned int i = 0; i < glyph_count; i++) {
            hb_codepoint_t gid = glyph_info[i].codepoint;
            double x_offset = glyph_pos[i].x_offset / 64.0;
            double y_offset = glyph_pos[i].y_offset / 64.0;
            double x_advance = glyph_pos[i].x_advance / 64.0;
            double y_advance = glyph_pos[i].y_advance / 64.0;
            
            // FreeTypeでグリフをロードして描画
            error = FT_Load_Glyph(face, gid, FT_LOAD_DEFAULT);
            if (error)
                return false;
            error = FT_Render_Glyph(face->glyph, FT_RENDER_MODE_NORMAL);
            if (error)
                return false;
            
            FT_Bitmap& bitmap = face->glyph->bitmap;
            
            m_rendercb(*this, i, bitmap.width,bitmap.rows,bitmap.pitch, bitmap.buffer, cursor_x, cursor_y, x_offset, y_offset);
            
            // 実際の描画位置 = (cursor_x + x_offset, cursor_y + y_offset)
            
            cursor_x += x_advance;
            cursor_y += y_advance;
        }
    }
    
    return true;
}

/*
static void render(FT_Bitmap& bitmap) {
    for (int y = 0; y < bitmap.rows; y++) {
        for (int x = 0; x < bitmap.width; x++) {
            // ピクセルの輝度に応じて文字を変える（簡易的な可視化）
            unsigned char pixel = bitmap.buffer[y * bitmap.pitch + x];
            std::cout << (pixel > 128 ? "##" : (pixel > 0 ? ".." : "  "));
        }
        std::cout << std::endl;
    }
}
*/
