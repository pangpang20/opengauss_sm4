#!/bin/bash
set -e

OGHOME=${OGHOME:-/usr/local/opengauss}
export PATH=$OGHOME/bin:$PATH
export LD_LIBRARY_PATH=$OGHOME/lib:$LD_LIBRARY_PATH

echo "======================================"
echo "Checking SM4 extension status"
echo "======================================"
echo ""

if [ -f "$OGHOME/lib/postgresql/sm4.so" ]; then
    echo "✓ SM4 dynamic library exists"
    ls -lh $OGHOME/lib/postgresql/sm4.so
else
    echo "✗ SM4 dynamic library not found"
    echo ""
    echo "The OpenGauss image lacks complete development headers for compilation."
    echo "Please use one of the following solutions:"
    echo ""
    echo "Solution 1: Compile sm4.so on a machine with full OpenGauss development environment"
    echo "  1. Compile: make clean && make"
    echo "  2. Copy to container: docker cp sm4.so opengauss_sm4:$OGHOME/lib/postgresql/"
    echo ""
    echo "Solution 2: Use OpenGauss image with development tools"
    echo "  Switch to opengauss/opengauss-server image (manual database initialization required)"
    echo ""
    exit 1
fi

if [ -f "$OGHOME/share/postgresql/extension/sm4--1.0.sql" ]; then
    echo "✓ SM4 SQL definition exists"
    echo ""
    echo "======================================"
    echo "Ready to create SM4 functions"
    echo "======================================"
    echo ""
    echo "Run the following command to create functions:"
    echo "  gsql -d postgres -p 5432 -c \"\\i $OGHOME/share/postgresql/extension/sm4--1.0.sql\""
    echo ""
    echo "Then test:"
    echo "  gsql -d postgres -p 5432 -c \"SELECT sm4_c_encrypt_hex('Hello OpenGauss!', '1234567890abcdef');\""
else
    echo "✗ SM4 SQL definition not found"
    exit 1
fi