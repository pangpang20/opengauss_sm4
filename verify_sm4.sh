#!/bin/bash
# OpenGauss SM4扩展验证脚本
# 用于Docker环境

set -e

echo "========================================"
echo "OpenGauss SM4扩展验证脚本"
echo "========================================"
echo ""

# 数据库连接参数
DB_HOST="localhost"
DB_PORT="15432"
DB_NAME="postgres"
DB_USER="gaussdb"
DB_PASSWORD="Enmo@123"

# 等待数据库启动
echo "等待OpenGauss数据库启动..."
for i in {1..30}; do
    if PGPASSWORD=$DB_PASSWORD gsql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1" &> /dev/null; then
        echo "数据库已启动!"
        break
    fi
    echo "等待中... ($i/30)"
    sleep 2
done

# 检查数据库是否启动成功
if ! PGPASSWORD=$DB_PASSWORD gsql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1" &> /dev/null; then
    echo "错误: 数据库启动失败!"
    exit 1
fi

echo ""
echo "========================================"
echo "步骤1: 创建SM4扩展函数"
echo "========================================"

PGPASSWORD=$DB_PASSWORD gsql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME << 'EOF'
-- 创建SM4 C扩展函数
CREATE OR REPLACE FUNCTION sm4_c_encrypt(plaintext text, key text)
RETURNS bytea AS 'sm4', 'sm4_encrypt' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION sm4_c_decrypt(ciphertext bytea, key text)
RETURNS text AS 'sm4', 'sm4_decrypt' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION sm4_c_encrypt_hex(plaintext text, key text)
RETURNS text AS 'sm4', 'sm4_encrypt_hex' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION sm4_c_decrypt_hex(ciphertext_hex text, key text)
RETURNS text AS 'sm4', 'sm4_decrypt_hex' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION sm4_c_encrypt_cbc(plaintext text, key text, iv text)
RETURNS bytea AS 'sm4', 'sm4_encrypt_cbc' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION sm4_c_decrypt_cbc(ciphertext bytea, key text, iv text)
RETURNS text AS 'sm4', 'sm4_decrypt_cbc' LANGUAGE C STRICT IMMUTABLE;

CREATE OR REPLACE FUNCTION sm4_c_encrypt_gcm(plaintext text, key text, iv text, aad text DEFAULT NULL)
RETURNS bytea AS 'sm4', 'sm4_encrypt_gcm' LANGUAGE C IMMUTABLE;

CREATE OR REPLACE FUNCTION sm4_c_decrypt_gcm(ciphertext_with_tag bytea, key text, iv text, aad text DEFAULT NULL)
RETURNS text AS 'sm4', 'sm4_decrypt_gcm' LANGUAGE C IMMUTABLE;

CREATE OR REPLACE FUNCTION sm4_c_encrypt_gcm_base64(plaintext text, key text, iv text, aad text DEFAULT NULL)
RETURNS text AS 'sm4', 'sm4_encrypt_gcm_base64' LANGUAGE C IMMUTABLE;

CREATE OR REPLACE FUNCTION sm4_c_decrypt_gcm_base64(ciphertext_base64 text, key text, iv text, aad text DEFAULT NULL)
RETURNS text AS 'sm4', 'sm4_decrypt_gcm_base64' LANGUAGE C IMMUTABLE;

\echo '✓ SM4扩展函数创建成功!'
EOF

echo ""
echo "========================================"
echo "步骤2: 查看已创建的函数"
echo "========================================"

PGPASSWORD=$DB_PASSWORD gsql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "\df sm4_c*"

echo ""
echo "========================================"
echo "步骤3: 测试ECB模式加解密"
echo "========================================"

PGPASSWORD=$DB_PASSWORD gsql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME << 'EOF'
-- 测试ECB模式
SELECT '测试1: ECB模式加密' AS test_name;
SELECT sm4_c_encrypt_hex('Hello OpenGauss!', '1234567890abcdef') AS encrypted_hex;

SELECT '测试2: ECB模式解密' AS test_name;
SELECT sm4_c_decrypt_hex(
    sm4_c_encrypt_hex('Hello OpenGauss!', '1234567890abcdef'), 
    '1234567890abcdef'
) AS decrypted_text;

SELECT '测试3: 中文加密' AS test_name;
SELECT sm4_c_decrypt(
    sm4_c_encrypt('测试中文加密', '1234567890abcdef'),
    '1234567890abcdef'
) AS decrypted_chinese;
EOF

echo ""
echo "========================================"
echo "步骤4: 测试CBC模式加解密"
echo "========================================"

PGPASSWORD=$DB_PASSWORD gsql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME << 'EOF'
SELECT '测试CBC模式' AS test_name;
SELECT sm4_c_decrypt_cbc(
    sm4_c_encrypt_cbc('CBC模式测试数据', '1234567890abcdef', 'abcdef1234567890'),
    '1234567890abcdef',
    'abcdef1234567890'
) AS cbc_result;
EOF

echo ""
echo "========================================"
echo "步骤5: 测试GCM模式加解密"
echo "========================================"

PGPASSWORD=$DB_PASSWORD gsql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME << 'EOF'
SELECT '测试GCM模式(无AAD)' AS test_name;
SELECT sm4_c_decrypt_gcm(
    sm4_c_encrypt_gcm('Hello GCM!', '1234567890123456', '123456789012'),
    '1234567890123456',
    '123456789012'
) AS gcm_result;

SELECT '测试GCM模式(带AAD)' AS test_name;
SELECT sm4_c_decrypt_gcm(
    sm4_c_encrypt_gcm('Secret Message', '1234567890123456', '123456789012', 'user_id:12345'),
    '1234567890123456',
    '123456789012',
    'user_id:12345'
) AS gcm_with_aad;

SELECT '测试GCM Base64模式' AS test_name;
SELECT sm4_c_decrypt_gcm_base64(
    sm4_c_encrypt_gcm_base64('Test Data', '1234567890123456', '123456789012'),
    '1234567890123456',
    '123456789012'
) AS gcm_base64_result;
EOF

echo ""
echo "========================================"
echo "验证完成! SM4扩展工作正常"
echo "========================================"
echo ""
echo "提示: 您可以运行以下命令进行更多测试:"
echo "  docker exec -it opengauss-sm4 gsql -d postgres -U gaussdb -f /opt/test_sm4.sql"
echo "  docker exec -it opengauss-sm4 gsql -d postgres -U gaussdb -f /opt/test_sm4_gcm.sql"
echo ""
