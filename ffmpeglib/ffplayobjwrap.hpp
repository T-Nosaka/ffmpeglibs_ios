//
//  ffplayobjwrap.hpp
//  ffmpeglib
//
//  Created by Takashi Nosaka on 2025/11/27.
//

#ifndef ffplayobjwrap_hpp
#define ffplayobjwrap_hpp

#import <swift/bridging>

#include <stdint.h>
#include <string>

class ffplayobj;

class ffplayobjwrap {
protected:
    ffplayobj* player;
    
public:
    ffplayobjwrap();
   
    virtual ~ffplayobjwrap();

    static void Delete(ffplayobjwrap*);
    
    void setAudio( bool bAudio );
    void setVideo( bool bVideo );
    void setSubTitle( bool bSubtitle );
    void setAutoexit( bool bAutoexit );
    void setStartTime( int64_t stime );
    void setDuration( int64_t dtime );

    void audiocallback(uint8_t* stream, int len);
    
    void setExtCallback( void* ext,
                        bool (*onexit)(void*) = nullptr,
                        void (*onclock)(void*,double,double,int) = nullptr,
                        void (*upload_texture_cb)(void*, int width, int height, int format, const void *pixels, int pitch) = nullptr,
                        bool (*oncontrol)(void*,int64_t* control, float* fargs) = nullptr,
                        bool (*readyaudiodevice)(void*, int channel, int sample_rate ) = nullptr,
                        void (*onstartaudio)(void*) = nullptr,
                        void (*onstopaudio)(void*) = nullptr,
                        void (*update_subtile_cb)(void*) = nullptr );

    int play(const char* strfilename,const float speed, const char* vfilter, const char* afilter );
} SWIFT_UNSAFE_REFERENCE;

#endif /* ffplayobjwrap_hpp */
