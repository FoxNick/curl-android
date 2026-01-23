#!/bin/bash
set -e

# 设置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_DIR="$SCRIPT_DIR/build_deps"
mkdir -p "$DEPS_DIR"
cd "$DEPS_DIR"

# 设置编译器
export TOOLCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
export AR="$TOOLCHAIN/bin/llvm-ar"
export CC="$TOOLCHAIN/bin/${CLANG_TARGET}-clang"
export CXX="$TOOLCHAIN/bin/${CLANG_TARGET}-clang++"
export LD="$TOOLCHAIN/bin/ld"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"
export SYSROOT="$TOOLCHAIN/sysroot"

# 通用编译函数
build_lib() {
    local name=$1
    local version=$2
    local url=$3
    local extra_flags=$4
    
    echo "Building $name $version..."
    
    if [ ! -f "${name}-${version}.tar.gz" ]; then
        wget -q "$url"
    fi
    
    tar -xzf "${name}-${version}.tar.gz"
    cd "${name}-${version}"
    
    mkdir -p build
    cd build
    
    ../configure \
        --host="${TARGET}" \
        --prefix="$DEPS_DIR/install" \
        --enable-static \
        --disable-shared \
        --disable-dependency-tracking \
        --with-sysroot="$SYSROOT" \
        $extra_flags \
        CFLAGS="-Os -fPIE -fPIC" \
        CXXFLAGS="-Os -fPIE -fPIC" \
        AR="$AR" \
        CC="$CC" \
        CXX="$CXX" \
        LD="$LD" \
        RANLIB="$RANLIB"
    
    make -j$(nproc)
    make install
    cd ../..
}

# 编译 libxml2
build_lib "libxml2" "2.11.7" \
    "https://download.gnome.org/sources/libxml2/2.11/libxml2-2.11.7.tar.xz" \
    "--without-python --without-lzma"

# 编译 openssl
echo "Building OpenSSL..."
OPENSSL_VERSION="3.1.4"
if [ ! -f "openssl-${OPENSSL_VERSION}.tar.gz" ]; then
    wget -q "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
fi
tar -xzf "openssl-${OPENSSL_VERSION}.tar.gz"
cd "openssl-${OPENSSL_VERSION}"
./Configure \
    linux-generic32 \
    --prefix="$DEPS_DIR/install" \
    --libdir=lib \
    no-shared \
    no-dso \
    no-ui-console \
    -D__ANDROID_API__=${ANDROID_API} \
    --cross-compile-prefix="${TARGET}-"
make -j$(nproc)
make install_sw
cd ..

# 编译 curl
build_lib "curl" "8.5.0" \
    "https://curl.se/download/curl-8.5.0.tar.gz" \
    "--with-openssl=$DEPS_DIR/install --without-ssl --without-libssh2 --without-librtmp --without-libidn2 --without-brotli --without-zstd"

# 编译 sqlite
SQLITE_VERSION="3440000"
echo "Building SQLite..."
if [ ! -f "sqlite-autoconf-${SQLITE_VERSION}.tar.gz" ]; then
    wget -q "https://www.sqlite.org/2024/sqlite-autoconf-${SQLITE_VERSION}.tar.gz"
fi
tar -xzf "sqlite-autoconf-${SQLITE_VERSION}.tar.gz"
cd "sqlite-autoconf-${SQLITE_VERSION}"
mkdir -p build
cd build
../configure \
    --host="${TARGET}" \
    --prefix="$DEPS_DIR/install" \
    --enable-static \
    --disable-shared \
    --disable-readline \
    CFLAGS="-Os -fPIE -fPIC -DSQLITE_ENABLE_COLUMN_METADATA -DSQLITE_ENABLE_FTS3 -DSQLITE_ENABLE_FTS4 -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_JSON1 -DSQLITE_ENABLE_RTREE -DSQLITE_MAX_VARIABLE_NUMBER=250000" \
    AR="$AR" \
    CC="$CC" \
    LD="$LD"
make -j$(nproc)
make install
cd ../..

# 编译 oniguruma (mbstring依赖)
build_lib "onig" "6.9.9" \
    "https://github.com/kkos/oniguruma/releases/download/v6.9.9/onig-6.9.9.tar.gz" \
    ""

# 编译 libzip
build_lib "libzip" "1.10.1" \
    "https://libzip.org/download/libzip-1.10.1.tar.gz" \
    "--without-bzip2 --without-lzma --without-zstd"

echo "Dependencies built successfully!"
