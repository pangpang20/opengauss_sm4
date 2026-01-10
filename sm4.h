/*
 * SM4 Algorithm Header
 * 国密SM4分组密码算法
 */

#ifndef SM4_H
#define SM4_H

#include <stdint.h>
#include <stddef.h>

#define SM4_BLOCK_SIZE  16
#define SM4_KEY_SIZE    16
#define SM4_KEY_SIZE_HEX 32
#define SM4_IV_SIZE     16
#define SM4_IV_SIZE_HEX 32
#define SM4_NUM_ROUNDS  32
#define SM4_GCM_IV_SIZE 12
#define SM4_GCM_TAG_SIZE 16
#define SM4_GCM_MAX_AAD_SIZE 1024
#define SM4_GCM_MAX_INPUT_SIZE 1024

typedef enum {
    SM4_SUCCESS = 0,
    SM4_ERROR_INVALID_KEY = -1,
    SM4_ERROR_INVALID_IV = -2,
    SM4_ERROR_INVALID_INPUT = -3,
    SM4_ERROR_MEMORY_ALLOCATION = -4,
    SM4_ERROR_INVALID_PADDING = -5,
    SM4_ERROR_AUTH_FAILED = -6,
    SM4_ERROR_BUFFER_TOO_SMALL = -7,
    SM4_ERROR_INPUT_TOO_LARGE = -8
} sm4_error_code;

typedef struct {
    uint32_t rk[SM4_NUM_ROUNDS];  /* 轮密钥 */
} sm4_context;

/*
 * SM4密钥扩展
 * @param ctx: SM4上下文
 * @param key: 16字节密钥
 */
void sm4_setkey(sm4_context *ctx, const uint8_t *key);

/*
 * SM4加密单个块(16字节)
 * @param ctx: SM4上下文
 * @param input: 16字节明文
 * @param output: 16字节密文
 */
void sm4_encrypt_block(const sm4_context *ctx, const uint8_t *input, uint8_t *output);

/*
 * SM4解密单个块(16字节)
 * @param ctx: SM4上下文
 * @param input: 16字节密文
 * @param output: 16字节明文
 */
void sm4_decrypt_block(const sm4_context *ctx, const uint8_t *input, uint8_t *output);

/*
 * SM4 ECB模式加密
 * @param key: 16字节密钥
 * @param input: 输入数据
 * @param input_len: 输入长度
 * @param output: 输出缓冲区(需预分配，长度为PKCS7填充后的大小)
 * @param output_len: 输出长度指针
 * @return: 0成功，-1失败
 */
int sm4_ecb_encrypt(const uint8_t *key, const uint8_t *input, size_t input_len,
                    uint8_t *output, size_t *output_len);

/*
 * SM4 ECB模式解密
 * @param key: 16字节密钥
 * @param input: 输入数据
 * @param input_len: 输入长度(必须是16的倍数)
 * @param output: 输出缓冲区
 * @param output_len: 输出长度指针
 * @return: 0成功，-1失败
 */
int sm4_ecb_decrypt(const uint8_t *key, const uint8_t *input, size_t input_len,
                    uint8_t *output, size_t *output_len);

/*
 * SM4 CBC模式加密
 * @param key: 16字节密钥
 * @param iv: 16字节初始向量
 * @param input: 输入数据
 * @param input_len: 输入长度
 * @param output: 输出缓冲区
 * @param output_len: 输出长度指针
 * @return: 0成功，-1失败
 */
int sm4_cbc_encrypt(const uint8_t *key, const uint8_t *iv,
                    const uint8_t *input, size_t input_len,
                    uint8_t *output, size_t *output_len);

/*
 * SM4 CBC模式解密
 * @param key: 16字节密钥
 * @param iv: 16字节初始向量
 * @param input: 输入数据
 * @param input_len: 输入长度
 * @param output: 输出缓冲区
 * @param output_len: 输出长度指针
 * @return: 0成功，-1失败
 */
int sm4_cbc_decrypt(const uint8_t *key, const uint8_t *iv,
                    const uint8_t *input, size_t input_len,
                    uint8_t *output, size_t *output_len);

/*
 * SM4 GCM模式加密
 * @param key: 16字节密钥
 * @param iv: 初始向量(推荐12字节)
 * @param iv_len: IV长度
 * @param aad: 附加认证数据(可选)
 * @param aad_len: AAD长度
 * @param input: 输入数据
 * @param input_len: 输入长度
 * @param output: 输出缓冲区(长度应为input_len)
 * @param tag: 认证标签输出(16字节)
 * @return: 0成功，-1失败
 */
int sm4_gcm_encrypt(const uint8_t *key, const uint8_t *iv, size_t iv_len,
                    const uint8_t *aad, size_t aad_len,
                    const uint8_t *input, size_t input_len,
                    uint8_t *output, uint8_t *tag);

/*
 * SM4 GCM模式解密
 * @param key: 16字节密钥
 * @param iv: 初始向量
 * @param iv_len: IV长度
 * @param aad: 附加认证数据(可选)
 * @param aad_len: AAD长度
 * @param input: 输入数据
 * @param input_len: 输入长度
 * @param tag: 认证标签(16字节)
 * @param output: 输出缓冲区
 * @return: 0成功，-1失败(认证失败或其他错误)
 */
int sm4_gcm_decrypt(const uint8_t *key, const uint8_t *iv, size_t iv_len,
                    const uint8_t *aad, size_t aad_len,
                    const uint8_t *input, size_t input_len,
                    const uint8_t *tag, uint8_t *output);

#endif /* SM4_H */