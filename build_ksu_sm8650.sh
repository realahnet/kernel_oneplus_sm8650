#!/bin/bash

echo -e "\n[INFO]: BUILD STARTED FOR KSU MODULE..!\n"

export KBUILD_BUILD_USER="@realahnet"

# Function to detect OS and install dependencies
install_dependencies() {
    echo -e "\n[INFO]: Detecting OS and installing dependencies...\n"

    if command -v dnf &> /dev/null; then
        echo -e "[INFO]: Fedora/RHEL-based system detected, using dnf...\n"
        sudo dnf group install "c-development" "development-tools" && \
        sudo dnf install -y dtc lz4 xz zlib-devel java-latest-openjdk-devel python3 \
            p7zip p7zip-plugins android-tools erofs-utils \
            ncurses-devel libX11-devel readline-devel mesa-libGL-devel python3-markdown \
            libxml2 libxslt dos2unix kmod openssl elfutils-libelf-devel dwarves \
            openssl-devel libarchive zstd rsync openssl-devel-engine --skip-unavailable

    elif command -v apt &> /dev/null; then
        echo -e "[INFO]: Ubuntu/Debian-based system detected, using apt...\n"
        sudo apt update && sudo apt install -y git device-tree-compiler lz4 xz-utils zlib1g-dev openjdk-17-jdk gcc g++ python3 python-is-python3 p7zip-full android-sdk-libsparse-utils erofs-utils \
            default-jdk git gnupg flex bison gperf build-essential zip curl libc6-dev libncurses-dev libx11-dev libreadline-dev libgl1 libgl1-mesa-dev \
            python3 make sudo gcc g++ bc grep tofrodos python3-markdown libxml2-utils xsltproc zlib1g-dev python-is-python3 libc6-dev libtinfo6 \
            make repo cpio kmod openssl libelf-dev pahole libssl-dev libarchive-tools zstd rsync --fix-missing && wget http://security.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2ubuntu0.1_amd64.deb && sudo dpkg -i libtinfo5_6.3-2ubuntu0.1_amd64.deb

    else
        echo -e "[ERROR]: Neither dnf nor apt package manager found. Please install dependencies manually.\n"
#        exit 1
    fi

    # Clone clang
    git clone --depth=1 https://github.com/realahnet/clang-r563880c toolchains/clang

    touch .requirements
}

# Install the requirements for building the kernel when running the script for the first time
if [ ! -f ".requirements" ]; then
    install_dependencies
fi

# Build options for the kernel
export BUILD_OPTIONS=(
    ARCH=arm64
    LLVM=toolchains/clang/bin/clang
)

clone_ksu() {
    curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -

    ast-grep -U -p '$$$ check_exports($$$) {$$$}' -r '' scripts/mod/modpost.c

    ast-grep -U -p 'check_exports($$$);' -r '' scripts/mod/modpost.c

    sed -i '/config KSU/,/help/{s/default y/default m/}' drivers/kernelsu/Kconfig
}

clone_ksun() {
    curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" | bash -

    ast-grep -U -p '$$$ check_exports($$$) {$$$}' -r '' scripts/mod/modpost.c

    ast-grep -U -p 'check_exports($$$);' -r '' scripts/mod/modpost.c

    sed -i '/config KSU/,/help/{s/default y/default m/}' drivers/kernelsu/Kconfig
}

build_mod(){
    # Build the KSU Module

    clone_ksu

    make "${BUILD_OPTIONS[@]}" O=out -j$(nproc --all) gki_defconfig vendor/pineapple_GKI.config vendor/oplus/pineapple_GKI.config || exit 1

    make "${BUILD_OPTIONS[@]}" O=out -j$(nproc --all) prepare modules_prepare || exit 1
    make "${BUILD_OPTIONS[@]}" O=out -j$(nproc --all) security/ || exit 1
    make "${BUILD_OPTIONS[@]}" O=out -j$(nproc --all) M=drivers/kernelsu modules || exit 1

    ./toolchains/clang/bin/llvm-objcopy --strip-debug out/drivers/kernelsu/kernelsu.ko ./kernelsu.ko

    rm -rf KernelSU/ drivers/kernelsu
    git restore drivers/ scripts/

    # Build the KSUN Module

    clone_ksun

    make "${BUILD_OPTIONS[@]}" O=out2 -j$(nproc --all) gki_defconfig vendor/pineapple_GKI.config vendor/oplus/pineapple_GKI.config || exit 1

    make "${BUILD_OPTIONS[@]}" O=out2 -j$(nproc --all) prepare modules_prepare || exit 1
    make "${BUILD_OPTIONS[@]}" O=out2 -j$(nproc --all) security/ || exit 1
    make "${BUILD_OPTIONS[@]}" O=out2 -j$(nproc --all) M=drivers/kernelsu modules || exit 1

    ./toolchains/clang/bin/llvm-objcopy --strip-debug out2/drivers/kernelsu/kernelsu.ko ./kernelsu_next.ko

    rm -rf KernelSU-Next/ drivers/kernelsu
    git restore drivers/ scripts/

    rm -rf out out2

    echo -e "\n[INFO]: BUILD FINISHED..!"
}

build_mod
