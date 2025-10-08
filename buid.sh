#!/bin/bash
curl -LSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s nongki
# 配置环境
echo "准备编译环境..."
export CCACHE_DIR="$HOME/.cache/ccache_yjkernel" 
export CC="ccache gcc"
export CXX="ccache g++"
export PATH="/usr/lib/ccache:$PATH"
echo "CCACHE_DIR: [$CCACHE_DIR]"

COMPILER="ARCH=arm64 SUBARCH=arm64 O=out CC=clang LD=ld.lld CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- CROSS_COMPILE_COMPAT=arm-linux-gnueabi-"



# 配置内核
echo "配置内核..."
#自行修改配置文件
make $COMPILER xtd_defconfig

scripts/config --file out/.config \
    --set-str STATIC_USERMODEHELPER_PATH /system/bin/micd \
    -d CPU_BIG_ENDIAN	\
    -e COMPAT_VDSO	\
    -e LTO_NONE	\
    -e INIT_STACK_NONE	\
    -d KPROBES	\
    -d SECCOMP

# 编译内核
echo "开始编译内核..."
make -j$(nproc) $COMPILER 2>&1 | tee error.log



# 检查编译错误
if grep -q "Error 2" "error.log"; then
    echo "编译过程中出现错误!"
    exit 1
fi
echo "内核编译完成!"



# 生成DTBO镜像 (如果需要)
GENERATE_DTBO=false
if [ "$GENERATE_DTBO" = true ]; then
    echo "生成DTBO镜像..."
    mkdir -p dtbo_tool
    cd dtbo_tool
    
    # 下载并解压dtbo工具
    if [ ! -f "mkdtboimg.tar.gz" ]; then
        curl -L https://android.googlesource.com/platform/system/libufdt/+archive/master/utils.tar.gz -o mkdtboimg.tar.gz
    fi
    tar -zxf mkdtboimg.tar.gz
    
    cd ..
    
    # 创建dtbo镜像
    DTBO_DIR="out/arch/arm64/boot/dts/vendor"
    if [ ! -d "$DTBO_DIR" ]; then
        DTBO_DIR="out/arch/arm64/boot/dts/qcom"
    fi
    
    if [ -d "$DTBO_DIR" ]; then
        python dtbo_tool/src/mkdtboimg.py create out/arch/arm64/boot/dtbo.img $DTBO_DIR/*.dtbo
        echo "DTBO镜像已生成: out/arch/arm64/boot/dtbo.img"
    else
        echo "警告: 未找到设备树文件目录"
    fi
fi

    cd out/arch/arm64/boot/
    wget https://github.com/aj4664/SukiSU_KernelPatch_patch/releases/download/0.12.2/patch_linux
    chmod +x patch_linux
    ./patch_linux
    cd -

cp -r out/arch/arm64/boot/ out123/cas/

echo "OK!"