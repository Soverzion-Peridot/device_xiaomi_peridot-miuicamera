#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=peridot-miuicamera
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        system/lib64/libgui-xiaomi.so)
            "${PATCHELF}" --set-soname libgui-xiaomi.so "${2}"
            ;;
        system/lib64/libcamera_algoup_jni.xiaomi.so)
            [ "$2" = "" ] && return 0
            grep -q "libgui-xiaomi.so" "${2}" || "${PATCHELF}" --add-needed libgui-xiaomi.so "${2}"
            "${SIGSCAN}" -p "08 AD 40 F9" -P "08 A9 40 F9" -f "${2}"
            ;;
        system/lib64/libcamera_mianode_jni.xiaomi.so)
            [ "$2" = "" ] && return 0
            grep -q "libgui-xiaomi.so" "${2}" || "${PATCHELF}" --add-needed libgui-xiaomi.so "${2}"
            ;;
        system/priv-app/MiuiCamera/MiuiCamera.apk)
            tmp_dir="${EXTRACT_TMP_DIR}/MiuiCamera"
            apktool -r d -q "$2" -o "$tmp_dir" -f
            grep -rl "com.miui.gallery" "$tmp_dir" | xargs sed -i 's|"com.miui.gallery"|"com.google.android.apps.photos"|g'
            apktool b -q "$tmp_dir" -o "$2"
            rm -rf "$tmp_dir"
            ;;
    esac
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
