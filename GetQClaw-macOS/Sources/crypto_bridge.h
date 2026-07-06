#ifndef CRYPTO_BRIDGE_H
#define CRYPTO_BRIDGE_H

#include <stdint.h>

int pbkdf2_sha1_derive(const uint8_t *password, int password_len,
                       const uint8_t *salt, int salt_len,
                       int iterations, uint8_t *derived_key, int key_len);

int aes128_cbc_decrypt(const uint8_t *key, int key_len,
                       const uint8_t *iv, int iv_len,
                       const uint8_t *cipher, int cipher_len,
                       uint8_t *plain, int *plain_len);

#endif