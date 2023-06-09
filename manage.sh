#!/bin/bash

set -o errexit -o nounset -o pipefail

source "$(dirname ${BASH_SOURCE[0]})/common.sh"

DELETE_TAG=

build_number=
if [[ $# -eq 1 ]]; then
    build_number=$1
elif [[ $# -ne 0 ]]; then
    user_error "expected 0 or 1 arguments"
fi

aosp_forks=(
    device_common
    device_generic_goldfish
    device_google_bonito
    device_google_bonito-sepolicy
    device_google_crosshatch
    device_google_crosshatch-sepolicy
    kernel_configs
    platform_art
    platform_bionic
    platform_bootable_recovery
    platform_build
    platform_build_soong
    platform_development
    platform_external_android-nn-driver
    platform_external_armnn
    platform_external_conscrypt
    platform_frameworks_av
    platform_frameworks_base
    platform_frameworks_ex
    platform_frameworks_libs_systemui
    platform_frameworks_native
    platform_frameworks_opt_net_wifi
    platform_hardware_google_pixel-sepolicy
    platform_libcore
    platform_manifest
    platform_packages_apps_Bluetooth
    platform_packages_apps_Calendar
    platform_packages_apps_CarrierConfig
    platform_packages_apps_Contacts
    platform_packages_apps_Dialer
    platform_packages_apps_DocumentsUI
    platform_packages_apps_EmergencyInfo
    platform_packages_apps_Gallery2
    platform_packages_apps_Launcher3
    platform_packages_apps_Nfc
    platform_packages_apps_Messaging
    platform_packages_apps_QuickSearchBox
    platform_packages_apps_RemoteProvisioner
    platform_packages_apps_Settings
    platform_packages_apps_SettingsIntelligence
    platform_packages_apps_ThemePicker
    platform_packages_apps_WallpaperPicker2
    platform_packages_inputmethods_LatinIME
    platform_packages_modules_Connectivity
    platform_packages_modules_common
    platform_packages_modules_NetworkStack
    platform_packages_modules_Permission
    platform_packages_modules_Wifi
    platform_packages_providers_DownloadProvider
    platform_packages_providers_MediaProvider
    platform_packages_providers_TelephonyProvider
    platform_packages_services_Telephony
    platform_system_bt
    platform_system_core
    platform_system_extras
    platform_system_netd
    platform_system_security
    platform_system_sepolicy
)

declare -A kernels=(
    # 2022-05-05 patch level
    [kernel_google_crosshatch]=android-12.1.0_r0.23
    [kernel_google_crosshatch_drivers_staging_qcacld-3.0]=android-12.1.0_r0.23
    [kernel_google_crosshatch_techpack_audio]=android-12.1.0_r0.23
)

independent=(
    android-prepare-vendor
    branding
    carriersettings-extractor
    device_google_blueline-kernel
    device_google_bonito-kernel
    device_google_crosshatch-kernel
    hardened_malloc
    platform_external_Apps
    platform_external_Auditor
    platform_external_Camera
    platform_external_PdfViewer
    platform_external_GmsCompatConfig
    platform_external_seedvault
    platform_external_talkback
    platform_external_vanadium
    platform_packages_apps_DeskClock # temporarily based on AOSP 11 instead of AOSP 12
    platform_packages_apps_ExactCalculator
    platform_packages_apps_GmsCompat
    platform_packages_apps_SetupWizard
    platform_packages_apps_Updater
    platform_themes
    script
)

for repo in "${aosp_forks[@]}"; do
    echo -e "\n>>> $(tput setaf 3)Handling $repo$(tput sgr0)"

    cd $repo

    git checkout $branch

    if [[ -n $DELETE_TAG ]]; then
        git tag -d $DELETE_TAG
        git push origin :refs/tags/$DELETE_TAG
        cd ..
        continue
    fi

    if [[ -n $build_number ]]; then
        if [[ $repo == platform_manifest ]]; then
            git checkout -B tmp
            sed -i s%refs/heads/$branch%refs/tags/$aosp_version.$build_number% default.xml
            git commit default.xml -m $aosp_version.$build_number
            git push -fu origin tmp
        else
            git tag -s $aosp_version.$build_number -m $aosp_version.$build_number
            git push origin $aosp_version.$build_number
        fi
    else
        git fetch upstream --tags

        git pull --rebase upstream $aosp_tag
        git push -f
    fi

    cd ..
done

for repo in ${!kernels[@]}; do
    echo -e "\n>>> $(tput setaf 3)Handling $repo$(tput sgr0)"

    cd $repo
    git checkout $branch

    if [[ -n $DELETE_TAG ]]; then
        git tag -d $DELETE_TAG
        git push origin :refs/tags/$DELETE_TAG
        cd ..
        continue
    fi

    if [[ -n $build_number ]]; then
        git tag -s $aosp_version.$build_number -m $aosp_version.$build_number
        git push origin $aosp_version.$build_number
    else
        git fetch upstream --tags
        kernel_tag=${kernels[$repo]}
        if [[ -z $kernel_tag ]]; then
            cd ..
            continue
        fi

        git checkout $branch
        git rebase $kernel_tag
        git push -f
    fi

    cd ..
done

for repo in ${independent[@]}; do
    echo -e "\n>>> $(tput setaf 3)Handling $repo$(tput sgr0)"

    cd $repo
    git checkout $branch

    if [[ -n $DELETE_TAG ]]; then
        git tag -d $DELETE_TAG
        git push origin :refs/tags/$DELETE_TAG
        cd ..
        continue
    fi

    if [[ -n $build_number ]]; then
        git tag -s $aosp_version.$build_number -m $aosp_version.$build_number
        git push origin $aosp_version.$build_number
    else
        git push -f
    fi

    cd ..
done
