/*
 * crypto.h - 内置加密/哈希工具（纯源码，无外部依赖）
 *
 * 把原 core/src/crypto_impl.h 提升到 common 层。所有模块都可以
 * 使用此处的 API。
 *
 * 实现分文件存放在 cpp/common/src/crypto/ 子目录，避免单一 header
 * 过于庞大。本 header 仅暴露公共 API 入口。
 *
 * 支持跨平台编译（Windows/Linux/Android/iOS/macOS）。
 */

#ifndef COMMON_CRYPTO_H
#define COMMON_CRYPTO_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// ============================================================
// CRC32 (IEEE 802.3)
// ============================================================
uint32_t common_crc32_update(uint32_t crc, const unsigned char *data, size_t len);

// ============================================================
// MD5 (RFC 1321)
// ============================================================
typedef struct {
    uint32_t a, b, c, d;
    uint64_t total;
    unsigned char buf[64];
    size_t buflen;
} MD5Context;

void common_md5_init(MD5Context *ctx);
void common_md5_update(MD5Context *ctx, const unsigned char *data, size_t len);
void common_md5_final(MD5Context *ctx, unsigned char out[16]);

// ============================================================
// SHA1 (FIPS 180-1)
// ============================================================
typedef struct {
    uint32_t h[5];
    uint64_t total;
    unsigned char buf[64];
    size_t buflen;
} SHA1Context;

void common_sha1_init(SHA1Context *ctx);
void common_sha1_update(SHA1Context *ctx, const unsigned char *data, size_t len);
void common_sha1_final(SHA1Context *ctx, unsigned char out[20]);

// ============================================================
// SHA256 (FIPS 180-2)
// ============================================================
typedef struct {
    uint32_t h[8];
    uint64_t total;
    unsigned char buf[64];
    size_t buflen;
} SHA256Context;

void common_sha256_init(SHA256Context *ctx);
void common_sha256_update(SHA256Context *ctx, const unsigned char *data, size_t len);
void common_sha256_final(SHA256Context *ctx, unsigned char out[32]);
void common_sha256_once(const unsigned char *data, size_t len, unsigned char out[32]);

// ============================================================
// SHA512 (FIPS 180-2)
// ============================================================
typedef struct {
    uint64_t h[8];
    uint64_t total_hi, total_lo;
    unsigned char buf[128];
    size_t buflen;
} SHA512Context;

void common_sha512_init(SHA512Context *ctx);
void common_sha512_update(SHA512Context *ctx, const unsigned char *data, size_t len);
void common_sha512_final(SHA512Context *ctx, unsigned char out[64]);

// ============================================================
// AES-256 (FIPS 197)。块 16 字节，密钥 32 字节。
// ============================================================
typedef struct {
    unsigned char round_keys[15][16];
} AES256Key;

void common_aes256_key_expand(AES256Key *ks, const unsigned char key[32]);
void common_aes256_encrypt_block(const AES256Key *ks, const unsigned char in[16], unsigned char out[16]);
void common_aes256_decrypt_block(const AES256Key *ks, const unsigned char in[16], unsigned char out[16]);

#ifdef __cplusplus
}

// C++ 命名空间别名（兼容旧代码使用 cc:: 调用风格）
namespace common_crypto_alias {
    using ::MD5Context;
    using ::SHA1Context;
    using ::SHA256Context;
    using ::SHA512Context;
    using ::AES256Key;
}
#endif

#endif // COMMON_CRYPTO_H
