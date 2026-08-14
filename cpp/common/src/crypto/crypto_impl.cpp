/*
 * crypto_impl.cpp - common_sha256/common_sha512/common_aes256 C API 包装
 *
 * 内部实现位于 internal_impl.h（namespace core_crypto）。
 * 本文件提供面向 C/C++ 的 extern "C" 统一 API。
 */

#include "common/crypto.h"
#include "internal_impl.h"

#include <string.h>

// ============================================================
// SHA256
// ============================================================
extern "C" void common_sha256_init(SHA256Context *ctx) {
    core_crypto::SHA256Context *c = reinterpret_cast<core_crypto::SHA256Context *>(ctx);
    core_crypto::sha256_init(c);
}

extern "C" void common_sha256_update(SHA256Context *ctx,
                                     const unsigned char *data, size_t len) {
    core_crypto::SHA256Context *c = reinterpret_cast<core_crypto::SHA256Context *>(ctx);
    core_crypto::sha256_update(c, data, len);
}

extern "C" void common_sha256_final(SHA256Context *ctx, unsigned char out[32]) {
    core_crypto::SHA256Context *c = reinterpret_cast<core_crypto::SHA256Context *>(ctx);
    core_crypto::sha256_final(c, out);
}

extern "C" void common_sha256_once(const unsigned char *data, size_t len,
                                   unsigned char out[32]) {
    core_crypto::sha256_once(data, len, out);
}

// ============================================================
// SHA512
// ============================================================
extern "C" void common_sha512_init(SHA512Context *ctx) {
    core_crypto::SHA512Context *c = reinterpret_cast<core_crypto::SHA512Context *>(ctx);
    core_crypto::sha512_init(c);
}

extern "C" void common_sha512_update(SHA512Context *ctx,
                                     const unsigned char *data, size_t len) {
    core_crypto::SHA512Context *c = reinterpret_cast<core_crypto::SHA512Context *>(ctx);
    core_crypto::sha512_update(c, data, len);
}

extern "C" void common_sha512_final(SHA512Context *ctx, unsigned char out[64]) {
    core_crypto::SHA512Context *c = reinterpret_cast<core_crypto::SHA512Context *>(ctx);
    core_crypto::sha512_final(c, out);
}

// ============================================================
// SHA1
// ============================================================
extern "C" void common_sha1_init(SHA1Context *ctx) {
    core_crypto::SHA1Context *c = reinterpret_cast<core_crypto::SHA1Context *>(ctx);
    core_crypto::sha1_init(c);
}

extern "C" void common_sha1_update(SHA1Context *ctx,
                                   const unsigned char *data, size_t len) {
    core_crypto::SHA1Context *c = reinterpret_cast<core_crypto::SHA1Context *>(ctx);
    core_crypto::sha1_update(c, data, len);
}

extern "C" void common_sha1_final(SHA1Context *ctx, unsigned char out[20]) {
    core_crypto::SHA1Context *c = reinterpret_cast<core_crypto::SHA1Context *>(ctx);
    core_crypto::sha1_final(c, out);
}

// ============================================================
// AES-256
// ============================================================
extern "C" void common_aes256_key_expand(AES256Key *ks,
                                         const unsigned char key[32]) {
    core_crypto::AES256Key *k = reinterpret_cast<core_crypto::AES256Key *>(ks);
    core_crypto::aes256_key_expand(k, key);
}

extern "C" void common_aes256_encrypt_block(const AES256Key *ks,
                                            const unsigned char in[16],
                                            unsigned char out[16]) {
    const core_crypto::AES256Key *k =
        reinterpret_cast<const core_crypto::AES256Key *>(ks);
    core_crypto::aes256_encrypt_block(k, in, out);
}

extern "C" void common_aes256_decrypt_block(const AES256Key *ks,
                                            const unsigned char in[16],
                                            unsigned char out[16]) {
    const core_crypto::AES256Key *k =
        reinterpret_cast<const core_crypto::AES256Key *>(ks);
    core_crypto::aes256_decrypt_block(k, in, out);
}