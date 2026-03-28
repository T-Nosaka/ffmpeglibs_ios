//
//  UsingBlock.h
//  ffmpeglib
//
//  Created by Takashi Nosaka on 2026/03/28.
//

#ifndef USINGBLOCK_H
#define USINGBLOCK_H

#include <functional>

/*
 * スコープ内リソース管理
 */
class UsingBlock {
private:
    std::function<void(void*)> destroycall;
    void* Tag;
public:
    UsingBlock( const std::function<void(void*)> call, void* tag = NULL ) {
        destroycall = call;
        Tag = tag;
    }
    virtual ~UsingBlock() {
        destroycall(Tag);
    }
};

#endif
