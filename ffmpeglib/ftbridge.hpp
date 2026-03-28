
#ifndef ftbridge_hpp
#define ftbridge_hpp

#import <swift/bridging>
#include <functional>

/*
 * Freetypeブリッジラッパ
 */
class ftbridgewrap {
protected:
    
    std::function<void(ftbridgewrap&, int loop, int width, int rows, int pitch, const void *pixels, double cursor_x, double cursor_y, double x_offset, double y_offset )> m_rendercb;
    
public:
    ftbridgewrap() {}
    virtual ~ftbridgewrap(){}
    static void Delete(ftbridgewrap* p) {
        delete p;
    }

    /*
     * コールバック変換
     */
    void setRenderCallback( void* ext, void (*rendercb)(void*, int loop, int width, int rows, int pitch, const void *pixels, double cursor_x, double cursor_y, double x_offset, double y_offset) ) {
        m_rendercb = [ext,rendercb](ftbridgewrap& instance,int loop, int width, int rows, int pitch, const void *pixels, double cursor_x, double cursor_y, double x_offset, double y_offset) {
            rendercb( ext, loop, width, rows, pitch, pixels, cursor_x, cursor_y, x_offset, y_offset);
        };
    }
    
    /*
     * 画像生成
     */
    bool build(const char* fontpath, int fontsize, const char* strvalue );
} SWIFT_UNSAFE_REFERENCE;

#endif
