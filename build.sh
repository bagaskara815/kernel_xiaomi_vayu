#!/usr/bin/env bash

set -euo pipefail
export TZ=":Asia/Jakarta"

KERNEL_NAME="Derp-KSU"
KERNEL_TYPE="EAS"
PHONE="Poco X3 Pro"
DEVICE="vayu"

DEFCONFIG="${CONFIG:-vayu_defconfig}"
CODENAME="${CODENAME:-}"
THINLTO="${THINLTO:-1}"
DTBO_IMG="${DTBO_IMG:-1}"
USE_OUT_DIR="${USE_OUT_DIR:-1}"
NEUTRON_RELEASE="${NEUTRON_RELEASE:-latest}"

AK_REPO="https://github.com/bagaskara815/AnyKernel3"
AK_BRANCH="vayu"

TOKEN="${TOKEN:-}"
CHAT_ID="${CHAT_ID:-}"

export KBUILD_BUILD_USER=Bagaskara
export KBUILD_BUILD_HOST=DominatingMachine

if [[ -n "${DISABLE_LTO:-}" ]]; then THINLTO=0; fi

KERNEL_ROOT="$(dirname "$(readlink -f "$0")")"
cd "${KERNEL_ROOT}"

NEUTRON_DIR="${NEUTRON_DIR:-${KERNEL_ROOT}/.tools/neutron-clang}"
OUT="${KERNEL_ROOT}/out"
AK="${KERNEL_ROOT}/.tools/AnyKernel"

info(){ echo -e "\n[INFO]: $*\n"; }
die(){ echo -e "\n[ERROR]: $*\n" >&2; exit 1; }

install_neutron(){
    if "${NEUTRON_DIR}/bin/clang" --version >/dev/null 2>&1; then return 0; fi
    rm -rf "${NEUTRON_DIR}"
    info "Setting up Neutron Clang (${NEUTRON_RELEASE})..."
    mkdir -p "${NEUTRON_DIR}"
    local sync_arg="-S"
    if [[ "${NEUTRON_RELEASE}" != "latest" ]]; then sync_arg="-S=${NEUTRON_RELEASE}"; fi
    (
        cd "${NEUTRON_DIR}"
        curl -LfO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
        bash antman "${sync_arg}"
        if ! "${NEUTRON_DIR}/bin/clang" --version >/dev/null 2>&1; then
            bash antman --patch=glibc
        fi
    ) || { rm -rf "${NEUTRON_DIR}"; die "Failed to set up Neutron Clang"; }
    if ! "${NEUTRON_DIR}/bin/clang" --version >/dev/null 2>&1; then
        ldd "${NEUTRON_DIR}/bin/clang" 2>&1 | head -3 || true
        die "Neutron clang not runnable"
    fi
}

PKGS=(make bc bison flex pkg-config git curl wget tar xz-utils zip unzip cpio rsync
      kmod perl python3 python-is-python3 libssl-dev libelf-dev libncurses-dev
      zlib1g-dev libyaml-dev lz4 zstd device-tree-compiler)

install_deps(){
    if ! command -v dpkg &>/dev/null; then
        info "Non-apt system: make sure the build deps are installed."
        return 0
    fi
    local missing=() available=() p
    local SUDO="sudo"
    if [ "$(id -u)" = 0 ]; then SUDO=""; fi
    for p in "${PKGS[@]}"; do
        [ "$(dpkg-query -W -f='${db:Status-Status}' "$p" 2>/dev/null)" = installed ] || missing+=("$p")
    done
    [ "${#missing[@]}" = 0 ] && return 0
    for p in "${missing[@]}"; do apt-cache show "$p" &>/dev/null && available+=("$p"); done
    [ "${#available[@]}" = 0 ] && return 0
    info "Installing: ${available[*]}"
    ${SUDO} apt update -qq || true
    if ! ${SUDO} apt install -y --no-install-recommends "${available[@]}"; then
        info "apt could not install every package (continuing)"
    fi
}

install_anykernel(){
    if [[ -d "${AK}" ]]; then return 0; fi
    info "Cloning AnyKernel3 (${AK_BRANCH})..."
    git clone --no-tags --single-branch -b "${AK_BRANCH}" "${AK_REPO}" "${AK}"
}

if [ ! -f Makefile ] || [ ! -d arch/arm64 ]; then die "Run this from the kernel source root."; fi

export PATH="${NEUTRON_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${NEUTRON_DIR}/lib:${NEUTRON_DIR}/lib64:${LD_LIBRARY_PATH:-}"

install_deps
install_neutron
install_anykernel

if command -v ccache &>/dev/null; then
    for d in /usr/lib/ccache /usr/lib64/ccache /usr/libexec/ccache; do
        if [[ -d "$d" ]]; then export PATH="$d:${PATH}"; break; fi
    done
    export CCACHE_DIR="${CCACHE_DIR:-${KERNEL_ROOT}/.ccache}"
    export CCACHE_COMPILERCHECK="${CCACHE_COMPILERCHECK:-content}"
fi

GIT="$(git log --pretty=format:'%h' -1 2>/dev/null || true)"; GIT="${GIT:-nogit}"
KVERSION="${CODENAME}-${GIT}"
ENDZ="${GIT}-$(date '+%d%m%Y-%H%M')"
ZIP_NAME="${KERNEL_NAME}${CODENAME}-${DEVICE}-${ENDZ}.zip"

if [[ "${USE_OUT_DIR}" = 1 ]]; then
    LOG_DIR="${OUT}"
else
    LOG_DIR="${KERNEL_ROOT}"
fi
mkdir -p "${LOG_DIR}"
LOG="${LOG_DIR}/${ZIP_NAME/.zip/.log}"
LOGE="${LOG_DIR}/${ZIP_NAME/.zip/.error.log}"

CLANG_BIN="${NEUTRON_DIR}/bin/clang"
KBUILD_COMPILER_STRING="$("${CLANG_BIN}" --version | head -n 1 | sed -e 's/(http.*)//g' -e 's/  */ /g' -e 's/[[:space:]]*$//')"

BUILD_OPTIONS=(
    -j"$(nproc)"
    ARCH=arm64
    LLVM=1
    LLVM_IAS=1
    CLANG_TRIPLE=aarch64-linux-gnu-
    CROSS_COMPILE=aarch64-linux-gnu-
    LOCALVERSION="${KVERSION}"
)
if [[ "${USE_OUT_DIR}" = 1 ]]; then
    BUILD_OPTIONS+=(O="${OUT}")
    BOOT_DIR="${OUT}/arch/arm64/boot"
else
    BOOT_DIR="${KERNEL_ROOT}/arch/arm64/boot"
fi

IMG="${BOOT_DIR}/Image"
DTBO="${BOOT_DIR}/dtbo.img"
DTB_DIR="${BOOT_DIR}/dts/qcom"

TG_ENABLED=0
if [[ -n "${TOKEN}" && -n "${CHAT_ID}" ]]; then TG_ENABLED=1; fi

send_info(){
    [[ "${TG_ENABLED}" -eq 1 ]] || return 0
    curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
        -d chat_id="${CHAT_ID}" \
        -d "parse_mode=HTML" \
        -d text="$(
            for POST in "${@}"; do echo "${POST}"; done
        )" &>/dev/null || true
}

push(){
    [[ "${TG_ENABLED}" -eq 1 ]] || return 0
    [[ -f "$1" ]] || return 0
    curl -F document=@"$1" "https://api.telegram.org/bot${TOKEN}/sendDocument" \
        -F chat_id="${CHAT_ID}" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Build took $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s). | #Derp | <b>vayu</b>" \
        &>/dev/null || true
}

START=$(date +%s)

send_info "<b>----- Nightly Kernel For Derp -----</b>" \
    "<b>Device:</b> ${DEVICE} or ${PHONE}" \
    "<b>Name:</b> <code>${KERNEL_NAME}${KVERSION}</code>" \
    "<b>Kernel Version:</b> <code>$(make -s kernelversion 2>/dev/null || echo '?')</code>" \
    "<b>Type:</b> <code>${KERNEL_TYPE}</code>" \
    "<b>Branch:</b> <code>$(git branch --show-current)</code>" \
    "<b>Commit:</b> <code>$(git log --pretty=format:'%h : %s' -1)</code>" \
    "<b>Started on:</b> <code>$(hostname)</code>" \
    "<b>Compiler:</b> <code>${KBUILD_COMPILER_STRING}</code>"

info "Kernel $(make -s kernelversion 2>/dev/null || echo '?') | defconfig: ${DEFCONFIG} | clang: ${KBUILD_COMPILER_STRING}"

make "${BUILD_OPTIONS[@]}" "${DEFCONFIG}" >/dev/null
if [[ "${THINLTO}" = 1 ]]; then scripts/config --file "${LOG_DIR}/.config" -e CONFIG_THINLTO; fi
if [[ "${DTBO_IMG}" = 1 ]]; then scripts/config --file "${LOG_DIR}/.config" -e CONFIG_BUILD_ARM64_DTBO_IMG; fi

rm -f "${IMG}" "${DTBO}"
make "${BUILD_OPTIONS[@]}" > >(tee "${LOG}") 2> >(tee "${LOGE}" >&2) || true
sleep 1

END=$(date +%s)
DIFF=$((END - START))

if [[ ! -f "${IMG}" ]]; then
    push "${LOG}"
    push "${LOGE}"
    die "Build failed (no ${IMG})"
fi

make -C "${AK}" clean
cp "${IMG}" "${AK}"
cp "${DTBO}" "${AK}"
find "${DTB_DIR}" -name "*.dtb" -exec cat {} + >"${AK}/dtb"
make -C "${AK}" ZIP="${ZIP_NAME}" normal

mkdir -p "${KERNEL_ROOT}/dist"
cp -f "${AK}/${ZIP_NAME}" "${KERNEL_ROOT}/dist/"
cp -f "${IMG}" "${KERNEL_ROOT}/dist/"
cp -f "${DTBO}" "${KERNEL_ROOT}/dist/"
cp -f "${LOG}" "${KERNEL_ROOT}/dist/"
find "${DTB_DIR}" -name "*.dtb" -exec cat {} + >"${BOOT_DIR}/dtb.img"
cp -f "${BOOT_DIR}/dtb.img" "${KERNEL_ROOT}/dist/"

push "${AK}/${ZIP_NAME}"
push "${LOG}"
push "${IMG}"
push "${DTBO}"
push "${BOOT_DIR}/dtb.img"

echo "Build OK: dist/${ZIP_NAME} (${DIFF}s)"
