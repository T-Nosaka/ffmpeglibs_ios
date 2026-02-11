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
void ffplayobjwrap::setStartTime( int64_t stime ) {
    player->start_time = stime;
}
void ffplayobjwrap::setDuration( int64_t dtime ) {
    player->duration = dtime;
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
                               upload_texture_cb( ext, width, height, format, pixels, pitch);
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
