//
//  ffparse.cpp
//  ffmpeglib
//
//  Created by Takashi Nosaka on 2025/12/06.
//

#include<stdlib.h>

#include "ffparse.hpp"

#include "cJSON.h"

extern "C" {
void filedump( const char *filename, cJSON* root );
}

/*
 * メディアファイル解析
　*/
void ffparse( const char *filename, void* ext, void (*cb)(const char*, void*) ) {
    auto rootnode = cJSON_CreateObject();
    ::filedump( filename, rootnode );
    char* json_str = cJSON_Print(rootnode);
    cb(json_str,ext);
    free(json_str);
    cJSON_Delete(rootnode);
}

