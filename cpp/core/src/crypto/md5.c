/*
 * md5.c - MD5 (RFC 1321) 实现
 */

#include "crypto.h"
#include <string.h>

#define F(x, y, z) (((x) & (y)) | (~(x) & (z)))
#define G(x, y, z) (((x) & (z)) | ((y) & ~(z)))
#define H(x, y, z) ((x) ^ (y) ^ (z))
#define I(x, y, z) ((y) ^ ((x) | ~(z)))

#define ROTL(x, n) (((x) << (n)) | ((x) >> (32 - (n))))

#define STEP(f, a, b, c, d, x, t, s) \
    (a) += f((b), (c), (d)) + (x) + (t); \
    (a) = ROTL((a), (s)); \
    (a) += (b);

static void md5_transform(MD5Context *ctx, const unsigned char block[64]) {
    static const uint32_t K[64] = {
        0xd76aa478u, 0xe8c7b756u, 0x242070dbu, 0xc1bdceeeu, 0xf57c0fafu, 0x4787c62au, 0xa8304613u, 0xfd469501u,
        0x698098d8u, 0x8b44f7afu, 0xffff5bb1u, 0x895cd7beu, 0x6b901122u, 0xfd987193u, 0xa679438eu, 0x49b40821u,
        0xf61e2562u, 0xc040b340u, 0x265e5a51u, 0xe9b6c7aau, 0xd62f105du, 0x02441453u, 0xd8a1e681u, 0xe7d3fbc8u,
        0x21e1cde6u, 0xc33707d6u, 0xf4d50d87u, 0x455a14edu, 0xa9e3e905u, 0xfcefa3f8u, 0x676f02d9u, 0x8d2a4c8au,
        0xfffa3942u, 0x8771f681u, 0x6d9d6122u, 0xfde5380cu, 0xa4beea44u, 0x4bdecfa9u, 0xf6bb4b60u, 0xbebfbc70u,
        0x289b7ec6u, 0xeaa127fau, 0xd4ef3085u, 0x04881d05u, 0xd9d4d039u, 0xe6db99e5u, 0x1fa27cf8u, 0xc4ac5665u,
        0xf4292244u, 0x432aff97u, 0xab9423a7u, 0xfc93a039u, 0x655b59c3u, 0x8f0ccc92u, 0xffeff47du, 0x85845dd1u,
        0x6fa87e4fu, 0xfe2ce6e0u, 0xa3014314u, 0x4e0811a1u, 0xf7537e82u, 0xbd3af235u, 0x2ad7d2bbu, 0xeb86d391u
    };
    static const uint32_t S[64] = {
        7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
        5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20, 5,  9, 14, 20,
        4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
        6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
    };
    uint32_t M[16];
    for (int i = 0; i < 16; i++) {
        M[i] = (uint32_t)block[i * 4]
             | ((uint32_t)block[i * 4 + 1] << 8)
             | ((uint32_t)block[i * 4 + 2] << 16)
             | ((uint32_t)block[i * 4 + 3] << 24);
    }
    uint32_t a = ctx->a, b = ctx->b, c = ctx->c, d = ctx->d;
    for (int i = 0; i < 64; i++) {
        uint32_t f, g;
        if (i < 16)      { f = F(b, c, d); g = i; }
        else if (i < 32) { f = G(b, c, d); g = (5 * i + 1) % 16; }
        else if (i < 48) { f = H(b, c, d); g = (3 * i + 5) % 16; }
        else             { f = I(b, c, d); g = (7 * i) % 16; }
        uint32_t tmp = d;
        d = c; c = b;
        b += ROTL(a + f + K[i] + M[g], S[i]);
        a = tmp;
    }
    ctx->a += a; ctx->b += b; ctx->c += c; ctx->d += d;
}

void common_md5_init(MD5Context *ctx) {
    ctx->a = 0x67452301u; ctx->b = 0xefcdab89u;
    ctx->c = 0x98badcfeu; ctx->d = 0x10325476u;
    ctx->total = 0; ctx->buflen = 0;
}

void common_md5_update(MD5Context *ctx, const unsigned char *data, size_t len) {
    ctx->total += len;
    while (len > 0) {
        size_t take = 64 - ctx->buflen;
        if (take > len) take = len;
        memcpy(ctx->buf + ctx->buflen, data, take);
        ctx->buflen += take;
        data += take;
        len -= take;
        if (ctx->buflen == 64) {
            md5_transform(ctx, ctx->buf);
            ctx->buflen = 0;
        }
    }
}

void common_md5_final(MD5Context *ctx, unsigned char out[16]) {
    uint64_t bits = ctx->total * 8;
    unsigned char pad = 0x80;
    common_md5_update(ctx, &pad, 1);
    unsigned char zero = 0;
    while (ctx->buflen != 56) common_md5_update(ctx, &zero, 1);
    unsigned char lenbytes[8];
    for (int i = 0; i < 8; i++) lenbytes[i] = (unsigned char)(bits >> (8 * i));
    common_md5_update(ctx, lenbytes, 8);
    uint32_t vals[4] = { ctx->a, ctx->b, ctx->c, ctx->d };
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            out[i * 4 + j] = (unsigned char)(vals[i] >> (8 * j));
}
