#pragma once

#include <stddef.h>

/// Décompresseur zstd, hors de Compression.framework : iOS n'expose pas `COMPRESSION_ZSTD`.
/// Amalgame officiel de zstd 1.5.7 (BSD), décompression seulement.

unsigned long long MicaboZstdFrameContentSize(const void *src, size_t srcSize);
size_t MicaboZstdDecompress(void *dst, size_t dstCapacity, const void *src, size_t srcSize);
int MicaboZstdIsError(size_t code);
