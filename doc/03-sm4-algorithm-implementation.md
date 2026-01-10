# 第3篇:SM4 加密算法与 C++ 实现

## 课程目标

这篇教程深入学习 SM4 国密算法的原理、实现细节和实际应用，通过写C 代码掌握对称加密算法的核心思想。

## SM4 算法简介

### 什么是 SM4？

SM4 是中国国家密码管理局于 2012 年发布的分组密码算法，也称为"商用密码 SM4"。

基本参数:
- 分组长度:128 位（16 字节）
- 密钥长度:128 位（16 字节）
- 轮数:32 轮
- 结构:Feistel 网络结构

标准文档: GB/T 32907-2016

### 为什么用SM4？

1. 国家标准:满足中国密码合规要求
2. 安全性高:经过充分的密码学分析，抗已知攻击
3. 性能优秀:硬件实现效率高
4. 广泛应用:金融、政务、通信等领域

### SM4 vs AES 对比

| 特性 | SM4 | AES |
|------|-----|-----|
| 密钥长度 | 128 位 | 128/192/256 位 |
| 分组长度 | 128 位 | 128 位 |
| 轮数 | 32 轮 | 10/12/14 轮 |
| 结构 | 非平衡 Feistel | SPN 结构 |
| 标准 | 中国国标 | 国际标准 |

## SM4 算法原理

### 核心组件

SM4 算法包含以下核心组件:

1. S 盒（Substitution Box）:非线性替换表
2. 线性变换 L:混淆和扩散
3. 轮函数 F:每轮的变换函数
4. 密钥扩展:从主密钥生成 32 个轮密钥

### 算法流程图

```
明文 (128 bit)
    ↓
[初始变换]
    ↓
轮1: F(X, RK1)
轮2: F(X, RK2)
    ...
轮32: F(X, RK32)
    ↓
[反序变换]
    ↓
密文 (128 bit)
```

### S 盒（置换盒）

S 盒是一个 256 字节的查找表，提供非线性变换:

```c
static const uint8_t SM4_SBOX[256] = {
    0xd6, 0x90, 0xe9, 0xfe, 0xcc, 0xe1, 0x3d, 0xb7, 
    0x16, 0xb6, 0x14, 0xc2, 0x28, 0xfb, 0x2c, 0x05,
    // ... 共 256 个字节
};
```

作用 输入 1 字节 → 输出 1 字节（非线性映射）

### 线性变换 L

```c
L(B) = B ⊕ (B <<< 2) ⊕ (B <<< 10) ⊕ (B <<< 18) ⊕ (B <<< 24)
```

其中 `<<<` 表示循环左移。

C 代码实现:

```c
#define ROTL(x, n) (((x) << (n)) | ((x) >> (32 - (n))))

static uint32_t sm4_l(uint32_t x)
{
    return x ^ ROTL(x, 2) ^ ROTL(x, 10) ^ ROTL(x, 18) ^ ROTL(x, 24);
}
```

### 合成置换 τ（tau）

将 32 位字拆分为 4 个字节，分别通过S 盒:

```c
static uint32_t sm4_tau(uint32_t x)
{
    uint8_t a[4];
    a[0] = SM4_SBOX[(x >> 24) & 0xff];  // 高字节
    a[1] = SM4_SBOX[(x >> 16) & 0xff];
    a[2] = SM4_SBOX[(x >> 8) & 0xff];
    a[3] = SM4_SBOX[x & 0xff];          // 低字节
    
    return ((uint32_t)a[0] << 24) | ((uint32_t)a[1] << 16) | 
           ((uint32_t)a[2] << 8) | ((uint32_t)a[3]);
}
```

### 轮函数 T

T 变换 = τ 变换 + L 变换:

```c
static uint32_t sm4_t(uint32_t x)
{
    return sm4_l(sm4_tau(x));
}
```

## 动手实现:SM4 核心算法

### 定义数据结构

创建`sm4_simple.h`:

```c
#ifndef SM4_SIMPLE_H
#define SM4_SIMPLE_H

#include <stdint.h>

#define SM4_BLOCK_SIZE  16  // 128 bit = 16 bytes
#define SM4_KEY_SIZE    16
#define SM4_NUM_ROUNDS  32

typedef struct {
    uint32_t rk[SM4_NUM_ROUNDS];  // 32 个轮密钥
} sm4_context;

void sm4_setkey(sm4_context ctx, const uint8_t key);
void sm4_encrypt_block(const sm4_context ctx, const uint8_t input, uint8_t output);
void sm4_decrypt_block(const sm4_context ctx, const uint8_t input, uint8_t output);

#endif
```

### 实现密钥扩展

创建`sm4_simple.c`:

```c
#include "sm4_simple.h"
#include <string.h>

/ 系统参数 FK /
static const uint32_t SM4_FK[4] = {
    0xa3b1bac6, 0x56aa3350, 0x677d9197, 0xb27022dc
};

/ 固定参数 CK（前8个） /
static const uint32_t SM4_CK[32] = {
    0x00070e15, 0x1c232a31, 0x383f464d, 0x545b6269,
    0x70777e85, 0x8c939aa1, 0xa8afb6bd, 0xc4cbd2d9,
    // ... 完整的 32 个值见附录
};

/ S 盒（简化版，完整版见附录） /
static const uint8_t SM4_SBOX[256] = {
    0xd6, 0x90, 0xe9, 0xfe, 0xcc, 0xe1, 0x3d, 0xb7,
    // ... 共 256 字节
};

#define ROTL(x, n) (((x) << (n)) | ((x) >> (32 - (n))))

/ 字节序转换:大端序 /
static uint32_t load_u32_be(const uint8_t b)
{
    return ((uint32_t)b[0] << 24) |
           ((uint32_t)b[1] << 16) |
           ((uint32_t)b[2] << 8)  |
           ((uint32_t)b[3]);
}

static void store_u32_be(uint8_t b, uint32_t v)
{
    b[0] = (uint8_t)(v >> 24);
    b[1] = (uint8_t)(v >> 16);
    b[2] = (uint8_t)(v >> 8);
    b[3] = (uint8_t)(v);
}

/ τ 变换 /
static uint32_t sm4_tau(uint32_t x)
{
    uint8_t a[4];
    a[0] = SM4_SBOX[(x >> 24) & 0xff];
    a[1] = SM4_SBOX[(x >> 16) & 0xff];
    a[2] = SM4_SBOX[(x >> 8) & 0xff];
    a[3] = SM4_SBOX[x & 0xff];
    return ((uint32_t)a[0] << 24) | ((uint32_t)a[1] << 16) | 
           ((uint32_t)a[2] << 8) | ((uint32_t)a[3]);
}

/ L' 变换（密钥扩展专用） /
static uint32_t sm4_l_prime(uint32_t x)
{
    return x ^ ROTL(x, 13) ^ ROTL(x, 23);
}

/ T' 变换（密钥扩展） /
static uint32_t sm4_t_prime(uint32_t x)
{
    return sm4_l_prime(sm4_tau(x));
}

/ 密钥扩展算法 /
void sm4_setkey(sm4_context ctx, const uint8_t key)
{
    uint32_t k[36];  // K0-K35
    int i;

    / MK 与 FK 异或 /
    k[0] = load_u32_be(key)      ^ SM4_FK[0];
    k[1] = load_u32_be(key + 4)  ^ SM4_FK[1];
    k[2] = load_u32_be(key + 8)  ^ SM4_FK[2];
    k[3] = load_u32_be(key + 12) ^ SM4_FK[3];

    / 生成 32 个轮密钥 /
    for (i = 0; i < SM4_NUM_ROUNDS; i++) {
        k[i + 4] = k[i] ^ sm4_t_prime(k[i + 1] ^ k[i + 2] ^ k[i + 3] ^ SM4_CK[i]);
        ctx->rk[i] = k[i + 4];
    }
}
```

### 实现加密函数

```c
/ L 变换（数据处理） /
static uint32_t sm4_l(uint32_t x)
{
    return x ^ ROTL(x, 2) ^ ROTL(x, 10) ^ ROTL(x, 18) ^ ROTL(x, 24);
}

/ T 变换（数据处理） /
static uint32_t sm4_t(uint32_t x)
{
    return sm4_l(sm4_tau(x));
}

/ SM4 加密单个块（128 位） /
void sm4_encrypt_block(const sm4_context ctx, const uint8_t input, uint8_t output)
{
    uint32_t x[36];  // X0-X35
    int i;

    / 加载明文 /
    x[0] = load_u32_be(input);
    x[1] = load_u32_be(input + 4);
    x[2] = load_u32_be(input + 8);
    x[3] = load_u32_be(input + 12);

    / 32 轮迭代 /
    for (i = 0; i < SM4_NUM_ROUNDS; i++) {
        x[i + 4] = x[i] ^ sm4_t(x[i + 1] ^ x[i + 2] ^ x[i + 3] ^ ctx->rk[i]);
    }

    / 反序变换输出密文 /
    store_u32_be(output,      x[35]);
    store_u32_be(output + 4,  x[34]);
    store_u32_be(output + 8,  x[33]);
    store_u32_be(output + 12, x[32]);
}

/ SM4 解密单个块 /
void sm4_decrypt_block(const sm4_context ctx, const uint8_t input, uint8_t output)
{
    uint32_t x[36];
    int i;

    x[0] = load_u32_be(input);
    x[1] = load_u32_be(input + 4);
    x[2] = load_u32_be(input + 8);
    x[3] = load_u32_be(input + 12);

    / 解密:轮密钥反向用/
    for (i = 0; i < SM4_NUM_ROUNDS; i++) {
        x[i + 4] = x[i] ^ sm4_t(x[i + 1] ^ x[i + 2] ^ x[i + 3] ^ ctx->rk[31 - i]);
    }

    store_u32_be(output,      x[35]);
    store_u32_be(output + 4,  x[34]);
    store_u32_be(output + 8,  x[33]);
    store_u32_be(output + 12, x[32]);
}
```

### 测试程序

创建`test_sm4.c`:

```c
#include <stdio.h>
#include <string.h>
#include "sm4_simple.h"

void print_hex(const char label, const uint8_t data, size_t len)
{
    printf("%s: ", label);
    for (size_t i = 0; i < len; i++) {
        printf("%02x", data[i]);
    }
    printf("\n");
}

int main()
{
    sm4_context ctx;
    
    / 测试向量（来自 GB/T 32907-2016） /
    uint8_t key[16] = {
        0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef,
        0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10
    };
    
    uint8_t plaintext[16] = {
        0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef,
        0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10
    };
    
    uint8_t ciphertext[16];
    uint8_t decrypted[16];
    
    / 标准答案 /
    uint8_t expected[16] = {
        0x68, 0x1e, 0xdf, 0x34, 0xd2, 0x06, 0x96, 0x5e,
        0x86, 0xb3, 0xe9, 0x4f, 0x53, 0x6e, 0x42, 0x46
    };
    
    / 测试加密 /
    printf("=== SM4 加密测试 ===\n");
    print_hex("密钥    ", key, 16);
    print_hex("明文    ", plaintext, 16);
    
    sm4_setkey(&ctx, key);
    sm4_encrypt_block(&ctx, plaintext, ciphertext);
    
    print_hex("密文    ", ciphertext, 16);
    print_hex("期望密文", expected, 16);
    
    if (memcmp(ciphertext, expected, 16) == 0) {
        printf("√ 加密测试通过！\n\n");
    } else {
        printf("✗ 加密测试失败！\n\n");
        return 1;
    }
    
    / 测试解密 /
    printf("=== SM4 解密测试 ===\n");
    sm4_decrypt_block(&ctx, ciphertext, decrypted);
    print_hex("解密结果", decrypted, 16);
    
    if (memcmp(decrypted, plaintext, 16) == 0) {
        printf("√ 解密测试通过！\n");
    } else {
        printf("✗ 解密测试失败！\n");
        return 1;
    }
    
    return 0;
}
```

### 编译和运行

```bash
# 编译
gcc -o test_sm4 test_sm4.c sm4_simple.c -Wall

# 运行
./test_sm4
```

输出:
```
=== SM4 加密测试 ===
密钥    : 0123456789abcdeffedcba9876543210
明文    : 0123456789abcdeffedcba9876543210
密文    : 681edf34d206965e86b3e94f536e4246
期望密文: 681edf34d206965e86b3e94f536e4246
√ 加密测试通过！

=== SM4 解密测试 ===
解密结果: 0123456789abcdeffedcba9876543210
√ 解密测试通过！
```

## SM4 工作模式

块加密算法需要工作模式来处理超过一个块的数据:

### 1. ECB 模式（电子密码本）

特点: 每个块独立加密

```
明文块1 → [SM4加密] → 密文块1
明文块2 → [SM4加密] → 密文块2
明文块3 → [SM4加密] → 密文块3
```

优点: 简单、可并行  
缺点: 相同明文产生相同密文，不够安全

### 2. CBC 模式（密码块链接）

特点: 每个块与前一个密文块异或

```
IV ⊕ 明文块1 → [SM4加密] → 密文块1
密文块1 ⊕ 明文块2 → [SM4加密] → 密文块2
```

实现示例:

```c
void sm4_cbc_encrypt(const uint8_t key, const uint8_t iv,
                     const uint8_t input, size_t input_len,
                     uint8_t output)
{
    sm4_context ctx;
    sm4_setkey(&ctx, key);
    
    uint8_t block[16];
    memcpy(block, iv, 16);  // 初始化向量
    
    for (size_t i = 0; i < input_len; i += 16) {
        / XOR 当前明文块与前一个密文块 /
        for (int j = 0; j < 16; j++) {
            block[j] ^= input[i + j];
        }
        
        / 加密 /
        sm4_encrypt_block(&ctx, block, output + i);
        
        / 更新链接块 /
        memcpy(block, output + i, 16);
    }
}
```

### 3. GCM 模式（Galois/Counter Mode）

特点: 认证加密，同时提供机密性和完整性

优点: 高性能、并行化、防篡改  
应用: TLS 1.3、IPsec

## 练习

### 实现PKCS#7 填充

在 ECB/CBC 模式中，数据长度需要是 16 字节的倍数。实现PKCS#7 填充:

```c
// 如果数据长度为 13，需要填充 3 字节，每个字节的值为 0x03
// 原始: [D1 D2 ... D13]
// 填充: [D1 D2 ... D13 03 03 03]

int pkcs7_pad(const uint8_t input, size_t input_len,
              uint8_t output, size_t output_len)
{
    // TODO: 实现填充逻辑
}
```




```c
int pkcs7_pad(const uint8_t input, size_t input_len,
              uint8_t output, size_t output_len)
{
    size_t pad_len = 16 - (input_len % 16);
    
    memcpy(output, input, input_len);
    
    for (size_t i = 0; i < pad_len; i++) {
        output[input_len + i] = (uint8_t)pad_len;
    }
    
    output_len = input_len + pad_len;
    return 0;
}

int pkcs7_unpad(const uint8_t input, size_t input_len,
                uint8_t output, size_t output_len)
{
    if (input_len < 16 || input_len % 16 != 0) {
        return -1;  // 无效的填充数据
    }
    
    uint8_t pad_len = input[input_len - 1];
    
    if (pad_len < 1 || pad_len > 16) {
        return -1;
    }
    
    / 验证填充 /
    for (size_t i = input_len - pad_len; i < input_len; i++) {
        if (input[i] != pad_len) {
            return -1;
        }
    }
    
    output_len = input_len - pad_len;
    memcpy(output, input, output_len);
    
    return 0;
}
```


### 性能测试

编写程序测试 SM4 的加密速度（MB/s）。

### 实现文件加密工具

创建命令行工具加密/解密文件:

```bash
./sm4tool encrypt -k mykey.bin -i plain.txt -o cipher.bin
./sm4tool decrypt -k mykey.bin -i cipher.bin -o plain2.txt
```

## 安全注意事项

1. 密钥管理
   - 永远不要硬编码密钥
   - 使用安全的密钥派生函数（如 PBKDF2）
   - 定期轮换密钥

2. IV（初始化向量）
   - CBC/GCM 模式必须使用随机 IV
   - 每次加密使用不同的 IV
   - IV 可以公开，但必须不可预测

3. 避免 ECB 模式
   - ECB 会泄露数据模式
   - 生产环境应用CBC 或 GCM

4. 完整性保护
   - 用GCM 模式或添加 HMAC
   - 防止密文被篡改


- [GB/T 32907-2016 SM4分组密码算法](http://www.gmbz.org.cn/main/viewfile/20180108023812835219.html)
- [SM4 算法白皮书](http://www.oscca.gov.cn/sca/xxgk/2016-08/16/content_1002386.shtml)
- [GmSSL 开源项目](https://github.com/guanzhi/GmSSL)

## 附录:完整常量表

完整的 S 盒和 CK 常量请参考项目源码 `sm4.c` 文件。
