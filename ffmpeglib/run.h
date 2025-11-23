//
//  run.h
//  ffmpeglib
//
//  Created by Takashi Nosaka on 2025/11/19.
//

#ifndef run_h
#define run_h

#include <stdio.h>

int run(int argc, char **argv, void* pext, int (*callback)(void* pext, int is_last_report, int64_t timer_start, int64_t cur_time, int64_t pts));


#endif /* run_h */
