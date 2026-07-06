#include "crypto_bridge.h"
#include <CommonCrypto/CommonCrypto.h>
#include <CommonCrypto/CommonKeyDerivation.h>

int pbkdf2_sha1_derive(const uint8_t *password, int password_len,
                       const uint8_t *salt, int salt_len,
                       int iterations, uint8_t *derived_key, int key_len) {
    return CCKeyDerivationPBKDF(kCCPBKDF2,
                                (const char *)password, password_len,
                                salt, salt_len,
                                kCCPRFHmacAlgSHA1, iterations,
                                derived_key, key_len);
}

int aes128_cbc_decrypt(const uint8_t *key, int key_len,
                       const uint8_t *iv, int iv_len,
                       const uint8_t *cipher, int cipher_len,
                       uint8_t *plain, int *plain_len) {
    size_t moved = 0;
    CCCryptorStatus status = CCCrypt(kCCDecrypt, kCCAlgorithmAES,
                                     kCCOptionPKCS7Padding,
                                     key, key_len, iv,
                                     cipher, cipher_len,
                                     plain, *plain_len, &moved);
    *plain_len = (int)moved;
    return status;
}