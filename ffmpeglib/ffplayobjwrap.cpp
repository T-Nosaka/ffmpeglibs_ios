//
//  ffplayobjwrap.cpp
//  ffmpeglib
//
//  Created by Takashi Nosaka on 2025/11/27.
//

#include "ffplayobjwrap.hpp"

#include "ffplayobj.h"

extern "C" {
//DUMMY Function
SDL_bool SDL_IsIPad(void) {
    return SDL_bool::SDL_FALSE;
}
}

ffplayobjwrap::ffplayobjwrap() {
    player = new ffplayobj();
    m_pixeldata = nullptr;
    m_pixeldata_length = 0;
}

ffplayobjwrap::~ffplayobjwrap() {
    delete player;
    if( m_pixeldata != nullptr) {
        delete m_pixeldata;
        m_pixeldata = nullptr;
        m_pixeldata_length = 0;
    }
}

void ffplayobjwrap::Delete(ffplayobjwrap* p) {
    delete p;
}

void ffplayobjwrap::setAudio( bool bAudio ) {
    player->setAudio( bAudio);
}
void ffplayobjwrap::setVideo( bool bVideo ) {
    player->setVideo( bVideo);
}
void ffplayobjwrap::setSubTitle( bool bSubtitle ) {
    player->setSubTitle( bSubtitle);
}
void ffplayobjwrap::setAutoexit( bool bAutoexit ) {
    player->setAutoexit( bAutoexit);
}

void ffplayobjwrap::audiocallback(uint8_t* stream, int len) {
    player->audiocallback( stream, len);
}

void ffplayobjwrap::setExtCallback( void* ext,
                                   bool (*onexit)(void*),
                                   void (*onclock)(void*,double,double,int),
                                   void (*upload_texture_cb)(void*, int width, int height, int format, const void *pixels, int pitch),
                                   bool (*oncontrol)(void*,int64_t* control, float* fargs),
                                   bool (*readyaudiodevice)(void*, int channel, int sample_rate ),
                                   void (*onstartaudio)(void*),
                                   void (*onstopaudio)(void*),
                                   void (*update_subtile_cb)(void*) ) {
    
    player->setExtCallback(
                           [this,ext,onexit](ffplayobj& instance) {
                               return onexit(ext);
                           },
                           [this,ext,onclock](ffplayobj& instance, double pos, double clock, int pause ) {
                               onclock( ext, pos, clock, pause );
                           },
                           [this,ext,upload_texture_cb](ffplayobj& instance,int width, int height, int format, const void *pixels, int pitch) {
                               auto numPixels = width * height;
                               alloc_pixeldata(numPixels);
                               //Repackaging bgra into an Integer Array
                               auto srcPixels = static_cast<const uint8_t*>(pixels);
                               
                               if( width*4 == pitch ) {
                                   memcpy( m_pixeldata , srcPixels, height*pitch );
                               } else {
                                   for (int y = 0; y < height; ++y) {
                                       const uint8_t* row = srcPixels + y * pitch;
                                       memcpy( reinterpret_cast<uint8_t*>(m_pixeldata + y * width) , row, width*4 );
                                   }
                               }
                               upload_texture_cb( ext, width, height, format, m_pixeldata, width*sizeof(uint32_t));
                           },
                           [this,ext,oncontrol](ffplayobj& instance,int64_t* control, float* fargs) {
                               //req seek
                               control[0]=0;
                               //none
                               control[1]=0;
                               //req pause
                               control[2]=0;
                               //step value
                               control[3]=0;
                               //step maxvalue
                               control[4]=0;
                               //seek value
                               fargs[0]=0;
                               return oncontrol( ext, control, fargs);
                           },
                           [this,ext,readyaudiodevice]( ffplayobj& instance, int channel, int sample_rate ){
                               return readyaudiodevice( ext, channel, sample_rate );
                           } ,
                           [this,ext,onstartaudio]( ffplayobj& instance) {
                               onstartaudio(ext);
                           },
                           [this,ext,onstopaudio]( ffplayobj& instance){
                               onstopaudio(ext);
                           },
                           [this,ext,update_subtile_cb](ffplayobj& instance, AVSubtitle& avsubtitle) {
                               update_subtile_cb(ext);
                           }
                        );
}

int ffplayobjwrap::play(const char* strfilename, const char* vfilter, const char* afilter ) {
    return player->play(strfilename,vfilter,afilter);
}
