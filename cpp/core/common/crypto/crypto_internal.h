/*
 * crypto_impl.h - 内置加密/哈希实现（纯源码，无任何外部依赖）
 *
 * 提供：CRC32 / MD5 / SHA1 / SHA256 / SHA512 / AES-256-CBC
 * 全部为公开标准算法实现，可跨平台编译（Windows/Linux/Android/iOS/macOS）。
 * 用于替换 OpenSSL（EVP）与 zlib（crc32）依赖，符合
 * "功能代码用 C++ 实现，不依赖系统能力，全部能力通过 app 内部源码集成" 的设计原则。
 *
 * 实现均为流式 API（init/update/final），支持大文件分块计算。
 */
#ifndef CRYPTO_IMPL_H
#define CRYPTO_IMPL_H

#include <stdint.h>
#include <stddef.h>
#include <string.h>

namespace core_crypto {

// ============================================================
// CRC32 (IEEE 802.3，与 zlib crc32() 输出一致)
// ============================================================
inline uint32_t crc32_update(uint32_t crc, const unsigned char* data, size_t len) {
    static uint32_t table[256];
    static int table_ready = 0;
    if (!table_ready) {
        for (uint32_t i = 0; i < 256; i++) {
            uint32_t c = i;
            for (int k = 0; k < 8; k++) {
                c = (c & 1) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1);
            }
            table[i] = c;
        }
        table_ready = 1;
    }
    crc = crc ^ 0xFFFFFFFFu;
    for (size_t i = 0; i < len; i++) {
        crc = table[(crc ^ data[i]) & 0xFFu] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFFu;
}

// ============================================================
// MD5 (RFC 1321)
// ============================================================
typedef struct {
    uint32_t a, b, c, d;
    uint64_t total;
    unsigned char buf[64];
    size_t buflen;
} MD5Context;

inline void md5_init(MD5Context* ctx) {
    ctx->a = 0x67452301u; ctx->b = 0xefcdab89u;
    ctx->c = 0x98badcfeu; ctx->d = 0x10325476u;
    ctx->total = 0; ctx->buflen = 0;
}

inline void md5_transform(MD5Context* ctx, const unsigned char* block) {
    static const uint32_t K[64] = {
        0xd76aa478u,0xe8c7b756u,0x242070dbu,0xc1bdceeeu,0xf57c0fafu,0x4787c62au,0xa8304613u,0xfd469501u,
        0x698098d8u,0x8b44f7afu,0xffff5bb1u,0x895cd7beu,0x6b901122u,0xfd987193u,0xa679438eu,0x49b40821u,
        0xf61e2562u,0xc040b340u,0x265e5a51u,0xe9b6c7aau,0xd62f105du,0x02441453u,0xd8a1e681u,0xe7d3fbc8u,
        0x21e1cde6u,0xc33707d6u,0xf4d50d87u,0x455a14edu,0xa9e3e905u,0xfcefa3f8u,0x676f02d9u,0x8d2a4c8au,
        0xfffa3942u,0x8771f681u,0x6d9d6122u,0xfde5380cu,0xa4beea44u,0x4bdecfa9u,0xf6bb4b60u,0xbebfbc70u,
        0x289b7ec6u,0xeaa127fau,0xd4ef3085u,0x04881d05u,0xd9d4d039u,0xe6db99e5u,0x1fa27cf8u,0xc4ac5665u,
        0xf4292244u,0x432aff97u,0xab9423a7u,0xfc93a039u,0x655b59c3u,0x8f0ccc92u,0xffeff47du,0x85845dd1u,
        0x6fa87e4fu,0xfe2ce6e0u,0xa3014314u,0x4e0811a1u,0xf7537e82u,0xbd3af235u,0x2ad7d2bbu,0xeb86d391u };
    static const int S[64] = {
        7,12,17,22, 7,12,17,22, 7,12,17,22, 7,12,17,22,
        5, 9,14,20, 5, 9,14,20, 5, 9,14,20, 5, 9,14,20,
        4,11,16,23, 4,11,16,23, 4,11,16,23, 4,11,16,23,
        6,10,15,21, 6,10,15,21, 6,10,15,21, 6,10,15,21 };
    uint32_t M[16];
    for (int i = 0; i < 16; i++) {
        M[i] = (uint32_t)block[i*4] | ((uint32_t)block[i*4+1] << 8) |
               ((uint32_t)block[i*4+2] << 16) | ((uint32_t)block[i*4+3] << 24);
    }
    uint32_t a = ctx->a, b = ctx->b, c = ctx->c, d = ctx->d;
    for (int i = 0; i < 64; i++) {
        uint32_t f; int g;
        if (i < 16)      { f = (b & c) | (~b & d);       g = i; }
        else if (i < 32) { f = (d & b) | (~d & c);       g = (5*i + 1) % 16; }
        else if (i < 48) { f = b ^ c ^ d;                g = (3*i + 5) % 16; }
        else             { f = c ^ (b | ~d);             g = (7*i) % 16; }
        uint32_t tmp = d;
        d = c; c = b;
        b = b + (((a + f + K[i] + M[g]) << S[i]) | ((a + f + K[i] + M[g]) >> (32 - S[i])));
        a = tmp;
    }
    ctx->a += a; ctx->b += b; ctx->c += c; ctx->d += d;
}

inline void md5_update(MD5Context* ctx, const unsigned char* data, size_t len) {
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

inline void md5_final(MD5Context* ctx, unsigned char out[16]) {
    uint64_t bits = ctx->total * 8;
    unsigned char pad = 0x80;
    md5_update(ctx, &pad, 1);
    unsigned char zero = 0;
    while (ctx->buflen != 56) md5_update(ctx, &zero, 1);
    unsigned char lenbytes[8];
    for (int i = 0; i < 8; i++) lenbytes[i] = (unsigned char)(bits >> (8*i));
    md5_update(ctx, lenbytes, 8);
    uint32_t vals[4] = { ctx->a, ctx->b, ctx->c, ctx->d };
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            out[i*4+j] = (unsigned char)(vals[i] >> (8*j));
}

// ============================================================
// SHA1 (FIPS 180-1)
// ============================================================
typedef struct {
    uint32_t h[5];
    uint64_t total;
    unsigned char buf[64];
    size_t buflen;
} SHA1Context;

inline void sha1_init(SHA1Context* ctx) {
    ctx->h[0] = 0x67452301u; ctx->h[1] = 0xEFCDAB89u;
    ctx->h[2] = 0x98BADCFEu; ctx->h[3] = 0x10325476u; ctx->h[4] = 0xC3D2E1F0u;
    ctx->total = 0; ctx->buflen = 0;
}

inline uint32_t rol32(uint32_t v, int n) { return (v << n) | (v >> (32 - n)); }

inline void sha1_transform(SHA1Context* ctx, const unsigned char* block) {
    uint32_t w[80];
    for (int i = 0; i < 16; i++)
        w[i] = ((uint32_t)block[i*4] << 24) | ((uint32_t)block[i*4+1] << 16) |
               ((uint32_t)block[i*4+2] << 8) | (uint32_t)block[i*4+3];
    for (int i = 16; i < 80; i++)
        w[i] = rol32(w[i-3] ^ w[i-8] ^ w[i-14] ^ w[i-16], 1);
    uint32_t a = ctx->h[0], b = ctx->h[1], c = ctx->h[2], d = ctx->h[3], e = ctx->h[4];
    for (int i = 0; i < 80; i++) {
        uint32_t f, k;
        if (i < 20)      { f = (b & c) | (~b & d);       k = 0x5A827999u; }
        else if (i < 40) { f = b ^ c ^ d;                k = 0x6ED9EBA1u; }
        else if (i < 60) { f = (b & c) | (b & d) | (c & d); k = 0x8F1BBCDCu; }
        else             { f = b ^ c ^ d;                k = 0xCA62C1D6u; }
        uint32_t tmp = rol32(a, 5) + f + e + k + w[i];
        e = d; d = c; c = rol32(b, 30); b = a; a = tmp;
    }
    ctx->h[0] += a; ctx->h[1] += b; ctx->h[2] += c; ctx->h[3] += d; ctx->h[4] += e;
}

inline void sha1_update(SHA1Context* ctx, const unsigned char* data, size_t len) {
    ctx->total += len;
    while (len > 0) {
        size_t take = 64 - ctx->buflen;
        if (take > len) take = len;
        memcpy(ctx->buf + ctx->buflen, data, take);
        ctx->buflen += take;
        data += take;
        len -= take;
        if (ctx->buflen == 64) {
            sha1_transform(ctx, ctx->buf);
            ctx->buflen = 0;
        }
    }
}

inline void sha1_final(SHA1Context* ctx, unsigned char out[20]) {
    uint64_t bits = ctx->total * 8;
    unsigned char pad = 0x80;
    sha1_update(ctx, &pad, 1);
    unsigned char zero = 0;
    while (ctx->buflen != 56) sha1_update(ctx, &zero, 1);
    unsigned char lenbytes[8];
    for (int i = 0; i < 8; i++) lenbytes[i] = (unsigned char)(bits >> (8*(7-i)));
    sha1_update(ctx, lenbytes, 8);
    for (int i = 0; i < 5; i++)
        for (int j = 0; j < 4; j++)
            out[i*4+j] = (unsigned char)(ctx->h[i] >> (8*(3-j)));
}

// ============================================================
// SHA256 (FIPS 180-2)
// ============================================================
typedef struct {
    uint32_t h[8];
    uint64_t total;
    unsigned char buf[64];
    size_t buflen;
} SHA256Context;

inline void sha256_init(SHA256Context* ctx) {
    static const uint32_t init[8] = {
        0x6a09e667u,0xbb67ae85u,0x3c6ef372u,0xa54ff53au,
        0x510e527fu,0x9b05688cu,0x1f83d9abu,0x5be0cd19u };
    memcpy(ctx->h, init, sizeof(init));
    ctx->total = 0; ctx->buflen = 0;
}

inline uint32_t ror32(uint32_t v, int n) { return (v >> n) | (v << (32 - n)); }

inline void sha256_transform(SHA256Context* ctx, const unsigned char* block) {
    static const uint32_t K[64] = {
        0x428a2f98u,0x71374491u,0xb5c0fbcfu,0xe9b5dba5u,0x3956c25bu,0x59f111f1u,0x923f82a4u,0xab1c5ed5u,
        0xd807aa98u,0x12835b01u,0x243185beu,0x550c7dc3u,0x72be5d74u,0x80deb1feu,0x9bdc06a7u,0xc19bf174u,
        0xe49b69c1u,0xefbe4786u,0x0fc19dc6u,0x240ca1ccu,0x2de92c6fu,0x4a7484aau,0x5cb0a9dcu,0x76f988dau,
        0x983e5152u,0xa831c66du,0xb00327c8u,0xbf597fc7u,0xc6e00bf3u,0xd5a79147u,0x06ca6351u,0x14292967u,
        0x27b70a85u,0x2e1b2138u,0x4d2c6dfcu,0x53380d13u,0x650a7354u,0x766a0abbu,0x81c2c92eu,0x92722c85u,
        0xa2bfe8a1u,0xa81a664bu,0xc24b8b70u,0xc76c51a3u,0xd192e819u,0xd6990624u,0xf40e3585u,0x106aa070u,
        0x19a4c116u,0x1e376c08u,0x2748774cu,0x34b0bcb5u,0x391c0cb3u,0x4ed8aa4au,0x5b9cca4fu,0x682e6ff3u,
        0x748f82eeu,0x78a5636fu,0x84c87814u,0x8cc70208u,0x90befffau,0xa4506cebu,0xbef9a3f7u,0xc67178f2u };
    uint32_t w[64];
    for (int i = 0; i < 16; i++)
        w[i] = ((uint32_t)block[i*4] << 24) | ((uint32_t)block[i*4+1] << 16) |
               ((uint32_t)block[i*4+2] << 8) | (uint32_t)block[i*4+3];
    for (int i = 16; i < 64; i++) {
        uint32_t s0 = ror32(w[i-15], 7) ^ ror32(w[i-15], 18) ^ (w[i-15] >> 3);
        uint32_t s1 = ror32(w[i-2], 17) ^ ror32(w[i-2], 19) ^ (w[i-2] >> 10);
        w[i] = w[i-16] + s0 + w[i-7] + s1;
    }
    uint32_t a = ctx->h[0], b = ctx->h[1], c = ctx->h[2], d = ctx->h[3];
    uint32_t e = ctx->h[4], f = ctx->h[5], g = ctx->h[6], h = ctx->h[7];
    for (int i = 0; i < 64; i++) {
        uint32_t S1 = ror32(e, 6) ^ ror32(e, 11) ^ ror32(e, 25);
        uint32_t ch = (e & f) ^ (~e & g);
        uint32_t t1 = h + S1 + ch + K[i] + w[i];
        uint32_t S0 = ror32(a, 2) ^ ror32(a, 13) ^ ror32(a, 22);
        uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
        uint32_t t2 = S0 + maj;
        h = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
    }
    ctx->h[0] += a; ctx->h[1] += b; ctx->h[2] += c; ctx->h[3] += d;
    ctx->h[4] += e; ctx->h[5] += f; ctx->h[6] += g; ctx->h[7] += h;
}

inline void sha256_update(SHA256Context* ctx, const unsigned char* data, size_t len) {
    ctx->total += len;
    while (len > 0) {
        size_t take = 64 - ctx->buflen;
        if (take > len) take = len;
        memcpy(ctx->buf + ctx->buflen, data, take);
        ctx->buflen += take;
        data += take;
        len -= take;
        if (ctx->buflen == 64) {
            sha256_transform(ctx, ctx->buf);
            ctx->buflen = 0;
        }
    }
}

inline void sha256_final(SHA256Context* ctx, unsigned char out[32]) {
    uint64_t bits = ctx->total * 8;
    unsigned char pad = 0x80;
    sha256_update(ctx, &pad, 1);
    unsigned char zero = 0;
    while (ctx->buflen != 56) sha256_update(ctx, &zero, 1);
    unsigned char lenbytes[8];
    for (int i = 0; i < 8; i++) lenbytes[i] = (unsigned char)(bits >> (8*(7-i)));
    sha256_update(ctx, lenbytes, 8);
    for (int i = 0; i < 8; i++)
        for (int j = 0; j < 4; j++)
            out[i*4+j] = (unsigned char)(ctx->h[i] >> (8*(3-j)));
}

// ============================================================
// SHA512 (FIPS 180-2, 64 位变体)
// ============================================================
typedef struct {
    uint64_t h[8];
    uint64_t total_hi, total_lo;
    unsigned char buf[128];
    size_t buflen;
} SHA512Context;

inline void sha512_init(SHA512Context* ctx) {
    static const uint64_t init[8] = {
        0x6a09e667f3bcc908ULL,0xbb67ae8584caa73bULL,0x3c6ef372fe94f82bULL,0xa54ff53a5f1d36f1ULL,
        0x510e527fade682d1ULL,0x9b05688c2b3e6c1fULL,0x1f83d9abfb41bd6bULL,0x5be0cd19137e2179ULL };
    memcpy(ctx->h, init, sizeof(init));
    ctx->total_hi = 0; ctx->total_lo = 0; ctx->buflen = 0;
}

inline uint64_t ror64(uint64_t v, int n) { return (v >> n) | (v << (64 - n)); }

inline void sha512_transform(SHA512Context* ctx, const unsigned char* block) {
    static const uint64_t K[80] = {
        0x428a2f98d728ae22ULL,0x7137449123ef65cdULL,0xb5c0fbcfec4d3b2fULL,0xe9b5dba58189dbbcULL,
        0x3956c25bf348b538ULL,0x59f111f1b605d019ULL,0x923f82a4af194f9bULL,0xab1c5ed5da6d8118ULL,
        0xd807aa98a3030242ULL,0x12835b0145706fbeULL,0x243185be4ee4b28cULL,0x550c7dc3d5ffb4e2ULL,
        0x72be5d74f27b896fULL,0x80deb1fe3b1696b1ULL,0x9bdc06a725c71235ULL,0xc19bf174cf692694ULL,
        0xe49b69c19ef14ad2ULL,0xefbe4786384f25e3ULL,0x0fc19dc68b8cd5b5ULL,0x240ca1cc77ac9c65ULL,
        0x2de92c6f592b0275ULL,0x4a7484aa6ea6e483ULL,0x5cb0a9dcbd41fbd4ULL,0x76f988da831153b5ULL,
        0x983e5152ee66dfabULL,0xa831c66d2db43210ULL,0xb00327c898fb213fULL,0xbf597fc7beef0ee4ULL,
        0xc6e00bf33da88fc2ULL,0xd5a79147930aa725ULL,0x06ca6351e003826fULL,0x142929670a0e6e70ULL,
        0x27b70a8546d22ffcULL,0x2e1b21385c26c926ULL,0x4d2c6dfc5ac42aedULL,0x53380d139d95b3dfULL,
        0x650a73548baf63deULL,0x766a0abb3c77b2a8ULL,0x81c2c92e47edaee6ULL,0x92722c851482353bULL,
        0xa2bfe8a14cf10364ULL,0xa81a664bbc423001ULL,0xc24b8b70d0f89791ULL,0xc76c51a30654be30ULL,
        0xd192e819d6ef5218ULL,0xd69906245565a910ULL,0xf40e35855771202aULL,0x106aa07032bbd1b8ULL,
        0x19a4c116b8d2d0c8ULL,0x1e376c085141ab53ULL,0x2748774cdf8eeb99ULL,0x34b0bcb5e19b48a8ULL,
        0x391c0cb3c5c95a63ULL,0x4ed8aa4ae3418acbULL,0x5b9cca4f7763e373ULL,0x682e6ff3d6b2b8a3ULL,
        0x748f82ee5defb2fcULL,0x78a5636f43172f60ULL,0x84c87814a1f0ab72ULL,0x8cc702081a6439ecULL,
        0x90befffa23631e28ULL,0xa4506cebde82bde9ULL,0xbef9a3f7b2c67915ULL,0xc67178f2e372532bULL,
        0xca273eceea26619cULL,0xd186b8c721c0c207ULL,0xeada7dd6cde0eb1eULL,0xf57d4f7fee6ed178ULL,
        0x06f067aa72176fbaULL,0x0a637dc5a2c898a6ULL,0x113f9804bef90daeULL,0x1b710b35131c471bULL,
        0x28db77f523047d84ULL,0x32caab7b40c72493ULL,0x3c9ebe0a15c9bebcULL,0x431d67c49c100d4cULL,
        0x4cc5d4becb3e42b6ULL,0x597f299cfc657e2aULL,0x5fcb6fab3ad6faecULL,0x6c44198c4a475817ULL };
    uint64_t w[80];
    for (int i = 0; i < 16; i++)
        w[i] = ((uint64_t)block[i*8] << 56) | ((uint64_t)block[i*8+1] << 48) |
               ((uint64_t)block[i*8+2] << 40) | ((uint64_t)block[i*8+3] << 32) |
               ((uint64_t)block[i*8+4] << 24) | ((uint64_t)block[i*8+5] << 16) |
               ((uint64_t)block[i*8+6] << 8) | (uint64_t)block[i*8+7];
    for (int i = 16; i < 80; i++) {
        uint64_t s0 = ror64(w[i-15], 1) ^ ror64(w[i-15], 8) ^ (w[i-15] >> 7);
        uint64_t s1 = ror64(w[i-2], 19) ^ ror64(w[i-2], 61) ^ (w[i-2] >> 6);
        w[i] = w[i-16] + s0 + w[i-7] + s1;
    }
    uint64_t a = ctx->h[0], b = ctx->h[1], c = ctx->h[2], d = ctx->h[3];
    uint64_t e = ctx->h[4], f = ctx->h[5], g = ctx->h[6], h = ctx->h[7];
    for (int i = 0; i < 80; i++) {
        uint64_t S1 = ror64(e, 14) ^ ror64(e, 18) ^ ror64(e, 41);
        uint64_t ch = (e & f) ^ (~e & g);
        uint64_t t1 = h + S1 + ch + K[i] + w[i];
        uint64_t S0 = ror64(a, 28) ^ ror64(a, 34) ^ ror64(a, 39);
        uint64_t maj = (a & b) ^ (a & c) ^ (b & c);
        uint64_t t2 = S0 + maj;
        h = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
    }
    ctx->h[0] += a; ctx->h[1] += b; ctx->h[2] += c; ctx->h[3] += d;
    ctx->h[4] += e; ctx->h[5] += f; ctx->h[6] += g; ctx->h[7] += h;
}

inline void sha512_update(SHA512Context* ctx, const unsigned char* data, size_t len) {
    ctx->total_lo += len;
    if (ctx->total_lo < (uint64_t)len) ctx->total_hi++;
    while (len > 0) {
        size_t take = 128 - ctx->buflen;
        if (take > len) take = len;
        memcpy(ctx->buf + ctx->buflen, data, take);
        ctx->buflen += take;
        data += take;
        len -= take;
        if (ctx->buflen == 128) {
            sha512_transform(ctx, ctx->buf);
            ctx->buflen = 0;
        }
    }
}

inline void sha512_final(SHA512Context* ctx, unsigned char out[64]) {
    uint64_t bits_lo = ctx->total_lo * 8;
    uint64_t bits_hi = ctx->total_hi * 8 + (ctx->total_lo >> 61);
    unsigned char pad = 0x80;
    sha512_update(ctx, &pad, 1);
    unsigned char zero = 0;
    while (ctx->buflen != 112) sha512_update(ctx, &zero, 1);
    unsigned char lenbytes[16];
    for (int i = 0; i < 8; i++) lenbytes[i] = (unsigned char)(bits_hi >> (8*(7-i)));
    for (int i = 0; i < 8; i++) lenbytes[8+i] = (unsigned char)(bits_lo >> (8*(7-i)));
    sha512_update(ctx, lenbytes, 16);
    for (int i = 0; i < 8; i++)
        for (int j = 0; j < 8; j++)
            out[i*8+j] = (unsigned char)(ctx->h[i] >> (8*(7-j)));
}

// ============================================================
// AES-256-CBC (FIPS 197)。块 16 字节，密钥 32 字节。
// ============================================================
typedef struct {
    unsigned char round_keys[15][16]; // 15 轮密钥（round 0..14）
} AES256Key;

inline void aes256_key_expand(AES256Key* ks, const unsigned char key[32]) {
    static const unsigned char sbox[256] = {
        0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
        0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
        0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
        0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
        0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
        0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
        0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
        0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
        0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
        0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
        0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
        0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
        0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
        0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
        0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
        0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16 };
    static const unsigned char rcon[10] = { 0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x1b,0x36 };
    unsigned char w[60][4];
    for (int i = 0; i < 8; i++) {
        w[i][0] = key[i*4]; w[i][1] = key[i*4+1]; w[i][2] = key[i*4+2]; w[i][3] = key[i*4+3];
    }
    for (int i = 8; i < 60; i++) {
        unsigned char t[4];
        if (i % 8 == 0) {
            t[0] = sbox[w[i-1][1]] ^ rcon[i/8 - 1];
            t[1] = sbox[w[i-1][2]];
            t[2] = sbox[w[i-1][3]];
            t[3] = sbox[w[i-1][0]];
        } else if (i % 8 == 4) {
            t[0] = sbox[w[i-1][0]]; t[1] = sbox[w[i-1][1]];
            t[2] = sbox[w[i-1][2]]; t[3] = sbox[w[i-1][3]];
        } else {
            t[0] = w[i-1][0]; t[1] = w[i-1][1]; t[2] = w[i-1][2]; t[3] = w[i-1][3];
        }
        w[i][0] = w[i-8][0] ^ t[0];
        w[i][1] = w[i-8][1] ^ t[1];
        w[i][2] = w[i-8][2] ^ t[2];
        w[i][3] = w[i-8][3] ^ t[3];
    }
    // 组织为 15 个 16 字节轮密钥（round 0..14）
    for (int r = 0; r < 15; r++)
        for (int i = 0; i < 4; i++)
            for (int j = 0; j < 4; j++)
                ks->round_keys[r][i*4+j] = w[r*4+i][j];
}

inline unsigned char gf_mul(unsigned char a, unsigned char b) {
    unsigned char p = 0;
    for (int i = 0; i < 8; i++) {
        if (b & 1) p ^= a;
        unsigned char hi = a & 0x80;
        a <<= 1;
        if (hi) a ^= 0x1b;
        b >>= 1;
    }
    return p;
}

inline void aes256_encrypt_block(const AES256Key* ks, const unsigned char in[16], unsigned char out[16]) {
    static const unsigned char sbox[256] = {
        0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
        0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
        0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
        0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
        0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
        0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
        0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
        0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
        0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
        0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
        0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
        0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
        0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
        0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
        0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
        0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16 };
    unsigned char st[16];
    memcpy(st, in, 16);
    for (int i = 0; i < 16; i++) st[i] ^= ks->round_keys[0][i];
    for (int round = 1; round < 14; round++) {
        for (int i = 0; i < 16; i++) st[i] = sbox[st[i]];
        // ShiftRows（FIPS 列主序存储：st[4*c+r] = state[r][c]）
        unsigned char t[16];
        for (int r = 0; r < 4; r++)
            for (int c = 0; c < 4; c++)
                t[4*c + r] = st[4*((c + r) % 4) + r];
        memcpy(st, t, 16);
        // MixColumns（列主序：列 c 的 4 字节连续存储在 st[4c..4c+3]）
        unsigned char col[4];
        for (int c = 0; c < 4; c++) {
            col[0] = st[4*c]; col[1] = st[4*c+1]; col[2] = st[4*c+2]; col[3] = st[4*c+3];
            st[4*c]   = gf_mul(col[0],2) ^ gf_mul(col[1],3) ^ col[2] ^ col[3];
            st[4*c+1] = col[0] ^ gf_mul(col[1],2) ^ gf_mul(col[2],3) ^ col[3];
            st[4*c+2] = col[0] ^ col[1] ^ gf_mul(col[2],2) ^ gf_mul(col[3],3);
            st[4*c+3] = gf_mul(col[0],3) ^ col[1] ^ col[2] ^ gf_mul(col[3],2);
        }
        for (int i = 0; i < 16; i++) st[i] ^= ks->round_keys[round][i];
    }
    for (int i = 0; i < 16; i++) st[i] = sbox[st[i]];
    unsigned char t[16];
    for (int r = 0; r < 4; r++)
        for (int c = 0; c < 4; c++)
            t[4*c + r] = st[4*((c + r) % 4) + r];
    memcpy(st, t, 16);
    for (int i = 0; i < 16; i++) st[i] ^= ks->round_keys[14][i];
    memcpy(out, st, 16);
}

inline void aes256_decrypt_block(const AES256Key* ks, const unsigned char in[16], unsigned char out[16]) {
    static const unsigned char inv_sbox[256] = {
        0x52,0x09,0x6a,0xd5,0x30,0x36,0xa5,0x38,0xbf,0x40,0xa3,0x9e,0x81,0xf3,0xd7,0xfb,
        0x7c,0xe3,0x39,0x82,0x9b,0x2f,0xff,0x87,0x34,0x8e,0x43,0x44,0xc4,0xde,0xe9,0xcb,
        0x54,0x7b,0x94,0x32,0xa6,0xc2,0x23,0x3d,0xee,0x4c,0x95,0x0b,0x42,0xfa,0xc3,0x4e,
        0x08,0x2e,0xa1,0x66,0x28,0xd9,0x24,0xb2,0x76,0x5b,0xa2,0x49,0x6d,0x8b,0xd1,0x25,
        0x72,0xf8,0xf6,0x64,0x86,0x68,0x98,0x16,0xd4,0xa4,0x5c,0xcc,0x5d,0x65,0xb6,0x92,
        0x6c,0x70,0x48,0x50,0xfd,0xed,0xb9,0xda,0x5e,0x15,0x46,0x57,0xa7,0x8d,0x9d,0x84,
        0x90,0xd8,0xab,0x00,0x8c,0xbc,0xd3,0x0a,0xf7,0xe4,0x58,0x05,0xb8,0xb3,0x45,0x06,
        0xd0,0x2c,0x1e,0x8f,0xca,0x3f,0x0f,0x02,0xc1,0xaf,0xbd,0x03,0x01,0x13,0x8a,0x6b,
        0x3a,0x91,0x11,0x41,0x4f,0x67,0xdc,0xea,0x97,0xf2,0xcf,0xce,0xf0,0xb4,0xe6,0x73,
        0x96,0xac,0x74,0x22,0xe7,0xad,0x35,0x85,0xe2,0xf9,0x37,0xe8,0x1c,0x75,0xdf,0x6e,
        0x47,0xf1,0x1a,0x71,0x1d,0x29,0xc5,0x89,0x6f,0xb7,0x62,0x0e,0xaa,0x18,0xbe,0x1b,
        0xfc,0x56,0x3e,0x4b,0xc6,0xd2,0x79,0x20,0x9a,0xdb,0xc0,0xfe,0x78,0xcd,0x5a,0xf4,
        0x1f,0xdd,0xa8,0x33,0x88,0x07,0xc7,0x31,0xb1,0x12,0x10,0x59,0x27,0x80,0xec,0x5f,
        0x60,0x51,0x7f,0xa9,0x19,0xb5,0x4a,0x0d,0x2d,0xe5,0x7a,0x9f,0x93,0xc9,0x9c,0xef,
        0xa0,0xe0,0x3b,0x4d,0xae,0x2a,0xf5,0xb0,0xc8,0xeb,0xbb,0x3c,0x83,0x53,0x99,0x61,
        0x17,0x2b,0x04,0x7e,0xba,0x77,0xd6,0x26,0xe1,0x69,0x14,0x63,0x55,0x21,0x0c,0x7d };
    unsigned char st[16];
    memcpy(st, in, 16);
    for (int i = 0; i < 16; i++) st[i] ^= ks->round_keys[14][i];
    for (int round = 13; round >= 1; round--) {
        // InvShiftRows（FIPS 列主序存储：st[4*c+r] = state[r][c]）
        unsigned char t[16];
        for (int r = 0; r < 4; r++)
            for (int c = 0; c < 4; c++)
                t[4*c + r] = st[4*((c - r + 4) % 4) + r];
        memcpy(st, t, 16);
        for (int i = 0; i < 16; i++) st[i] = inv_sbox[st[i]];
        for (int i = 0; i < 16; i++) st[i] ^= ks->round_keys[round][i];
        // InvMixColumns（列主序：列 c 的 4 字节连续存储在 st[4c..4c+3]）
        unsigned char col[4];
        for (int c = 0; c < 4; c++) {
            col[0] = st[4*c]; col[1] = st[4*c+1]; col[2] = st[4*c+2]; col[3] = st[4*c+3];
            st[4*c]   = gf_mul(col[0],14) ^ gf_mul(col[1],11) ^ gf_mul(col[2],13) ^ gf_mul(col[3],9);
            st[4*c+1] = gf_mul(col[0],9)  ^ gf_mul(col[1],14) ^ gf_mul(col[2],11) ^ gf_mul(col[3],13);
            st[4*c+2] = gf_mul(col[0],13) ^ gf_mul(col[1],9)  ^ gf_mul(col[2],14) ^ gf_mul(col[3],11);
            st[4*c+3] = gf_mul(col[0],11) ^ gf_mul(col[1],13) ^ gf_mul(col[2],9)  ^ gf_mul(col[3],14);
        }
    }
    unsigned char t[16];
    for (int r = 0; r < 4; r++)
        for (int c = 0; c < 4; c++)
            t[4*c + r] = st[4*((c - r + 4) % 4) + r];
    memcpy(st, t, 16);
    for (int i = 0; i < 16; i++) st[i] = inv_sbox[st[i]];
    for (int i = 0; i < 16; i++) st[i] ^= ks->round_keys[0][i];
    memcpy(out, st, 16);
}

// ============================================================
// 便捷一次性 API（内部使用）
// ============================================================
inline void sha256_once(const unsigned char* data, size_t len, unsigned char out[32]) {
    SHA256Context ctx;
    sha256_init(&ctx);
    sha256_update(&ctx, data, len);
    sha256_final(&ctx, out);
}

} // namespace core_crypto

#endif // CRYPTO_IMPL_H
