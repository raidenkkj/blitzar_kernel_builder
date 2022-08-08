#!/usr/bin/env bash
#
# Copyright (C) 2021 a xyzprjkt property
#

# Needed Secret Variable
# KERNEL_NAME | Your kernel name
# KERNEL_SOURCE | Your kernel link source
# KERNEL_BRANCH  | Your needed kernel branch if needed with -b. eg -b eleven_eas
# DEVICE_CODENAME | Your device codename
# DEVICE_DEFCONFIG | Your device defconfig eg. lavender_defconfig
# ANYKERNEL | Your Anykernel link repository
# TG_TOKEN | Your telegram bot token
# TG_CHAT_ID | Your telegram private ci chat id
# BUILD_USER | Your username
# BUILD_HOST | Your hostname

echo "|| Downloading few Dependecies . . .||"
# Kernel Sources
git clone --depth=1 $KERNEL_SOURCE -b msm-4.4-hmp $DEVICE_CODENAME
git clone --depth=1 https://github.com/cbendot/gcc-aarch64.git gcc64 # gcc64 set as Default
git clone --depth=1 https://github.com/cbendot/gcc-armv5.git gcc32 # gcc32 set as Default
# git clone --deoth=1 https://github.com/mvaisakh/gcc-arm64.git gcc64 # gcc64 set as Default
# git clone --depth=1 https://github.com/mvaisakh/gcc-arm.git gcc32 # gcc32 set as Default

# Main Declaration
KERNEL_ROOTDIR=$(pwd)/$DEVICE_CODENAME # IMPORTANT ! Fill with your kernel source root directory.
DEVICE_DEFCONFIG=$DEVICE_DEFCONFIG # IMPORTANT ! Declare your kernel source defconfig file here.
# CLANG_ROOTDIR=$(pwd)/clang
GCC64_ROOTDIR=$(pwd)/gcc64 # IMPORTANT! Put your GCC directory here.
GCC32_ROOTDIR=$(pwd)/gcc32 # IMPORTANT! Put your GCC directory here.
# export KBUILD_BUILD_USER=$BUILD_USER # Change with your own name or else.
# export KBUILD_BUILD_HOST=$BUILD_HOST # Change with your own hostname.

# Main Declaration
# CLANG_VER="$("$CLANG_ROOTDIR"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
GCC64_VER="$("$GCC64_ROOTDIR"/bin/aarch64-buildroot-linux-gnu-gcc --version | head -n 1)"
export KBUILD_COMPILER_STRING="$GCC64_VER"
IMAGE=$(pwd)/$DEVICE_CODENAME/out/arch/arm64/boot/Image.gz-dtb
DATE=$(date "+%B %-d, %Y")
ZIP_DATE=$(date +"%Y%m%d")
START=$(date +"%s")

# Checking environtment
# Warning !! Dont Change anything there without known reason.
function check() {
echo ================================================
echo xKernelCompiler
echo version : rev1.5 - gaspoll modified
echo ================================================
echo BUILDER NAME = ${KBUILD_BUILD_USER}
echo BUILDER HOSTNAME = ${KBUILD_BUILD_HOST}
echo DEVICE_DEFCONFIG = ${DEVICE_DEFCONFIG}
echo TOOLCHAIN_VERSION = ${KBUILD_COMPILER_STRING}
echo GCC64_ROOTDIR = ${GCC64_ROOTDIR}
echo GCC32_ROOTDIR = ${GCC32_ROOTDIR}
echo KERNEL_ROOTDIR = ${KERNEL_ROOTDIR}
echo ================================================
}

# Telegram
export BOT_MSG_URL="https://api.telegram.org/bot$TG_TOKEN/sendMessage"

tg_post_msg() {
  curl -s -X POST "$BOT_MSG_URL" -d chat_id="$TG_CHAT_ID" \
  -d "disable_web_page_preview=true" \
  -d "parse_mode=html" \
  -d text="$1"
}

# Post Main Information
tg_post_msg "<b>$KERNEL_NAME Triggered Build</b>%0A<b>Triggered by: </b><code>ben863</code>%0A<b>Build For: </b><code>$DEVICE_CODENAME</code>%0A<b>Build Date: </b><code>$DATE</code>%0A<b>Pipelines Hosts: </b><code>DroneCI</code>%0A<b>Source:</b> <code>$KERNEL_SOURCE</code>%0A<b>Toolchain Information:</b>%0A<code>${KBUILD_COMPILER_STRING}</code>"

# Compile
compile(){
cd ${KERNEL_ROOTDIR}
COMMIT_HEAD=$(git log --oneline -1)
tg_post_msg "<b>commit: </b>$COMMIT_HEAD"
make -j$(nproc) O=out ARCH=arm64 ${DEVICE_DEFCONFIG}
make -j$(nproc) ARCH=arm64 O=out \
    AR=${GCC64_ROOTDIR}/bin/aarch64-buildroot-linux-gnu-ar \
  	NM=${GCC64_ROOTDIR}/bin/aarch64-buildroot-linux-gnu-nm \
  	OBJCOPY=${GCC64_ROOTDIR}/bin/aarch64-buildroot-linux-gnu-objcopy \
  	OBJDUMP=${GCC64_ROOTDIR}/bin/aarch64-buildroot-linux-gnu-objdump \
    STRIP=${GCC64_ROOTDIR}/bin/aarch64-buildroot-linux-gnu-strip \
    CROSS_COMPILE=${GCC64_ROOTDIR}/bin/aarch64-buildroot-linux-gnu- \
    CROSS_COMPILE_ARM32=${GCC32_ROOTDIR}/bin/arm-buildroot-linux-gnueabi-

   if ! [ -a "$IMAGE" ]; then
	finerr
	exit 1
   fi

  git clone --depth=1 $ANYKERNEL AnyKernel
	cp $IMAGE AnyKernel
}

# Push kernel to channel
function push() {
    cd AnyKernel
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
        -F chat_id="$TG_CHAT_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="✅ $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s)"
}

# Fin Error
function finerr() {
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="❌ Build throw an error(s)"
    exit 1
}

# Zipping
function zipping() {
    cd AnyKernel || exit 1
    zip -r9 $KERNEL_NAME-HMP-${ZIP_DATE}.zip *
    cd ..

}
check
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push
