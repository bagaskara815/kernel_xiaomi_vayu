#!/usr/bin/env bash
#
# Copyright (C) 2021 @alanndz (Telegram and Github)
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Build script for vayu (Poco X3 Pro)
# Credit: Rama Bondan Prakoso (rama982)
#

export TZ=":Asia/Jakarta"

if [[ ! -f Makefile ]]; then
  echo "error: run this script from the kernel root"
  exit 1
fi

KDIR=$(pwd)
TC="${KDIR}/.tools"
AK=${TC}/AnyKernel
KERNEL_NAME="Derp-KSU"
KERNEL_TYPE="EAS"
PHONE="Poco X3 Pro"
DEVICE="vayu"
CONFIG=${CONFIG:-vayu_defconfig}
CHAT_ID="${CHAT_ID:-}"
TOKEN="${TOKEN:-}"
export KBUILD_BUILD_USER=Bagaskara
export KBUILD_BUILD_HOST=DominatingMachine
AK_BRANCH="vayu"

mkdir -p "$TC"
if [[ ! -x $TC/clang/clang-r547379/bin/clang ]]; then
  rm -rf "$TC/clang"
  git clone https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
    --depth=1 --no-tags --single-branch -b master "$TC/clang"
  find "$TC/clang" -mindepth 1 -maxdepth 1 -type d ! -name 'clang-r547379' -exec rm -rf {} +
  rm -rf "$TC/clang/.git" 2>/dev/null || true
fi
if [[ ! -d $TC/gcc64/bin ]]; then
  git clone https://github.com/mvaisakh/gcc-arm64 --depth=1 --no-tags --single-branch "$TC/gcc64"
  rm -rf "$TC/gcc64/.git" 2>/dev/null || true
fi
if [[ ! -d $TC/gcc32/bin ]]; then
  git clone https://github.com/mvaisakh/gcc-arm --depth=1 --no-tags --single-branch "$TC/gcc32"
  rm -rf "$TC/gcc32/.git" 2>/dev/null || true
fi
if [[ ! -d ${AK} ]]; then
  git clone https://github.com/bagaskara815/AnyKernel3 --no-tags --single-branch -b "$AK_BRANCH" "${AK}"
fi

GIT="$(git log --pretty=format:'%h' -1)"
ENDZ="${GIT}-$(date "+%d%m%Y-%H%M")"
KVERSION="${CODENAME:-}-${GIT}"
ZIP_NAME="${KERNEL_NAME}${CODENAME:-}-${DEVICE}-${ENDZ}.zip"
LOG=$(echo "${ZIP_NAME}" | sed "s/.zip/.log/")
LOGE=$(echo "${ZIP_NAME}" | sed "s/.zip/.error.log/")

IMG="$KDIR/out/arch/arm64/boot/Image"
DTBO="$KDIR/out/arch/arm64/boot/dtbo.img"
DTB="$KDIR/out/arch/arm64/boot/dts/qcom"
CL="$TC/clang/clang-r547379"

if [[ ! -x "${CL}/bin/clang" ]]; then
  echo "error: clang not found at ${CL}/bin/clang"
  exit 1
fi

if command -v ccache >/dev/null 2>&1 && [[ -d /usr/lib/ccache ]]; then
  export CCACHE_DIR="${CCACHE_DIR:-$KDIR/.ccache}"
  mkdir -p "$CCACHE_DIR"
  export CCACHE_COMPILERCHECK="${CCACHE_COMPILERCHECK:-content}"
  export PATH="/usr/lib/ccache:${CL}/bin:${TC}/gcc64/bin:${TC}/gcc32/bin:$PATH"
  KBUILD_COMPILER_STRING=$("${CL}/bin/clang" --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
  KBUILD_COMPILER_STRING="${KBUILD_COMPILER_STRING} + ccache"
else
  export PATH="${CL}/bin:${TC}/gcc64/bin:${TC}/gcc32/bin:$PATH"
  KBUILD_COMPILER_STRING=$("${CL}/bin/clang" --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
fi
export LD_LIBRARY_PATH="${CL}/lib:${LD_LIBRARY_PATH:-}"

START=$(date +"%s")
mkdir -p "$KDIR/out"

TG_ENABLED=0
[[ -n "${TOKEN}" && -n "${CHAT_ID}" ]] && TG_ENABLED=1

disable_lto() {
  scripts/config --file out/.config -e CONFIG_THINLTO
}

enable_dtbo() {
  scripts/config --file out/.config -e CONFIG_BUILD_ARM64_DTBO_IMG
}

m() {
  make -j"$(nproc --all)" O=out \
    ARCH=arm64 \
    LOCALVERSION="${KVERSION}" \
    CC="clang" \
    LLVM=1 \
    LLVM_IAS=1 \
    LD=ld.lld \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    CLANG_TRIPLE=aarch64-elf- \
    CROSS_COMPILE=aarch64-elf- \
    CROSS_COMPILE_ARM32=arm-eabi- \
    ${ENV:-} \
    "${@}"
}

m "${CONFIG}" >/dev/null
if [[ -z "${DISABLE_LTO:-}" ]]; then
  disable_lto
fi
enable_dtbo
m > >(tee "$KDIR/out/${LOG}") 2> >(tee "$KDIR/out/${LOGE}" >&2)

END=$(date +"%s")
DIFF=$((END - START))

sendInfo() {
  [[ "${TG_ENABLED}" -eq 1 ]] || return 0
  curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d "parse_mode=HTML" \
    -d text="$(
      for POST in "${@}"; do
        echo "${POST}"
      done
    )" &>/dev/null || true
}

sendInfo "<b>----- Nightly Kernel For Derp -----</b>" \
  "<b>Device:</b> ${DEVICE} or ${PHONE}" \
  "<b>Name:</b> <code>${KERNEL_NAME}${KVERSION}</code>" \
  "<b>Kernel Version:</b> <code>$(make kernelversion)</code>" \
  "<b>Type:</b> <code>${KERNEL_TYPE}</code>" \
  "<b>Branch:</b> <code>$(git branch --show-current)</code>" \
  "<b>Commit:</b> <code>$(git log --pretty=format:'%h : %s' -1)</code>" \
  "<b>Started on:</b> <code>$(hostname)</code>" \
  "<b>Compiler:</b> <code>${KBUILD_COMPILER_STRING}</code>"

push() {
  [[ "${TG_ENABLED}" -eq 1 ]] || return 0
  [[ -f "$1" ]] || return 0
  curl -F document=@"$1" "https://api.telegram.org/bot${TOKEN}/sendDocument" \
    -F chat_id="${CHAT_ID}" \
    -F "disable_web_page_preview=true" \
    -F "parse_mode=html" \
    -F caption="Build took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s). | #Derp | <b>vayu</b>" \
    &>/dev/null || true
}

if [[ ! -f ${IMG} ]]; then
  echo "error: build failed"
  push "out/${LOG}"
  push "out/${LOGE}"
  exit 1
fi

make -C "${AK}" clean
cp "${IMG}" "${AK}"
cp "${DTBO}" "${AK}"
find "${DTB}" -name "*.dtb" -exec cat {} + >"${AK}/dtb"
make -C "${AK}" ZIP="${ZIP_NAME}" normal

mkdir -p "${KDIR}/dist"
cp -f "${AK}/${ZIP_NAME}" "${KDIR}/dist/" 2>/dev/null || true
cp -f "${IMG}" "${KDIR}/dist/" 2>/dev/null || true
cp -f "${DTBO}" "${KDIR}/dist/" 2>/dev/null || true
cp -f "out/${LOG}" "${KDIR}/dist/" 2>/dev/null || true
find out/arch/arm64/boot/dts/qcom -name "*.dtb" -exec cat {} + >"${KDIR}/out/arch/arm64/boot/dtb.img"
cp -f "${KDIR}/out/arch/arm64/boot/dtb.img" "${KDIR}/dist/" 2>/dev/null || true

push "${AK}/${ZIP_NAME}"
push "out/${LOG}"
push "out/arch/arm64/boot/Image"
push "out/arch/arm64/boot/dtbo.img"
push "out/arch/arm64/boot/dtb.img"

echo "Build OK: dist/${ZIP_NAME} (${DIFF}s)"
