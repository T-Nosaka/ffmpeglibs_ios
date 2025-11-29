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
}

ffplayobjwrap::~ffplayobjwrap() {
    delete player;
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

void ffplayobjwrap::audiocallback(uint8_t *stream, int len) {
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
                               auto pixelData = new uint8_t(numPixels);
                               //Repackaging RGB24 into an Integer Array
                               auto srcPixels = static_cast<const uint8_t*>(pixels);
                               for (int y = 0; y < height; ++y) {
                                   const uint8_t* row = srcPixels + y * pitch;
                                   for (int x = 0; x < width; ++x) {
                                       uint8_t r = row[x * 3];
                                       uint8_t g = row[x * 3 + 1];
                                       uint8_t b = row[x * 3 + 2];
                                       pixelData[y * width + x] = (0xFF << 24) | (r << 16) | (g << 8) | b;
                                   }
                               }
                               
                               upload_texture_cb( ext, width, height, format, pixelData, pitch);
                           },
                           [this,ext,oncontrol](ffplayobj& instance,int64_t* control, float* fargs) {
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
