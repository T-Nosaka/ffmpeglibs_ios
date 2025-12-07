//
//  ffparse.hpp
//  ffmpeglib
//
//  Created by Takashi Nosaka on 2025/12/06.
//

#ifndef ffparse_hpp
#define ffparse_hpp

void ffparse( const char *filename, void* ext, void (*cb)(const char*, void*) );

#endif /* ffparse_hpp */
