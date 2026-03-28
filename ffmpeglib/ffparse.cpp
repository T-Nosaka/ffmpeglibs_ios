//
//  ffparse.cpp
//  ffmpeglib
//
//  Created by Takashi Nosaka on 2025/12/06.
//

#include<stdlib.h>

#include "ffparse.hpp"
#include "cJSON.h"
#include "usingblock.h"

extern "C" {
void filedump( const char *filename, cJSON* root );
}

/*
 * メディアファイル解析
　*/
void ffparse( const char *filename, void* ext, void (*cb)(const char*, void*) ) {
    auto rootnode = cJSON_CreateObject();
    auto rootnode_block = UsingBlock( [rootnode](void *_) {
        cJSON_Delete(rootnode);
    } );
    
    ::filedump( filename, rootnode );
    char* json_str = cJSON_Print(rootnode);
    auto json_str_block = UsingBlock( [json_str](void *_) {
        free(json_str);
    } );
    
    cb(json_str,ext);
}

