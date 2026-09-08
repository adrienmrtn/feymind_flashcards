#include "MicaboZstd.h"
#include "zstd.h"

unsigned long long MicaboZstdFrameContentSize(const void *src, size_t srcSize) {
    return ZSTD_getFrameContentSize(src, srcSize);
}

size_t MicaboZstdDecompress(void *dst, size_t dstCapacity, const void *src, size_t srcSize) {
    return ZSTD_decompress(dst, dstCapacity, src, srcSize);
}

int MicaboZstdIsError(size_t code) {
    return ZSTD_isError(code) ? 1 : 0;
}
