#!/bin/bash
set -e

echo "======================================"
echo "Installing SM4 encryption extension for OpenGauss"
echo "======================================"

if [ "$(id -u)" != "0" ]; then
    echo ""
    echo "Error: This script requires root privileges to install build tools"
    echo "Please run using:"
    echo "  docker exec -it opengauss_sm4 bash -c 'cd /opt/sm4_extension && bash install-sm4.sh'"
    echo ""
    exit 1
fi

echo ""
echo "0. Checking build tools..."
if ! command -v make &> /dev/null || ! command -v g++ &> /dev/null; then
    echo "   Build tools not installed, installing gcc, g++, make..."
    
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y gcc g++ make || {
            echo "   Warning: apt-get installation failed, attempting to continue..."
        }
    elif command -v yum &> /dev/null; then
        yum install -y gcc gcc-c++ make || {
            echo "   Warning: yum installation failed, attempting to continue..."
        }
    else
        echo "   Error: Package manager not found (apt-get or yum)"
        exit 1
    fi
else
    echo "   ✓ Build tools already installed"
fi

OGHOME=${OGHOME:-/usr/local/opengauss}
export PATH=$OGHOME/bin:$PATH
export LD_LIBRARY_PATH=$OGHOME/lib:$LD_LIBRARY_PATH

cd /opt/sm4_extension

echo ""
echo "1. Cleaning old files..."
make clean || true

echo ""
echo "2. Compiling SM4 extension..."
make

echo ""
echo "3. Installing SM4 extension..."
make install

echo ""
echo "4. Verifying installation..."
ls -lh $OGHOME/lib/postgresql/sm4.so
ls -lh $OGHOME/share/postgresql/extension/sm4*

echo ""
echo "======================================"
echo "✓ SM4 extension installation complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo ""
echo "5. Create SM4 functions:"
echo "   gsql -d postgres -p 5432 -c \"\\\\i $OGHOME/share/postgresql/extension/sm4--1.0.sql\""
echo ""
echo "6. Test SM4 encryption:"
echo "   gsql -d postgres -p 5432 -c \"SELECT sm4_c_encrypt_hex('Hello OpenGauss!', '1234567890abcdef');\""
echo ""