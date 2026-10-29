#!/usr/bin/bash
#
#           CasaOS (neo) Update Script
#
#   GitHub: https://github.com/Elephant-on-github/neo-casaos
#   Issues: https://github.com/Elephant-on-github/neo-casaos/issues
#   Requires: bash, wget, tar, systemctl (GNU coreutils: realpath, cut, sort, mktemp -p)
#
#   This script updates the three neo-owned CasaOS components (backend,
#   gateway, UI) to the pinned release versions below. Other CasaOS
#   services are left untouched.
#   Usage:
#
#   	  curl -fsSL https://raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/build/update.sh | sudo bash
#
#   In automated environments, you may want to run as root.
#   If using curl, we recommend using the -fsSL flags.
#

export PATH=/usr/sbin:$PATH
set -e

###############################################################################
# GLOBALS                                                                     #
###############################################################################

((EUID)) && sudo_cmd="sudo"

UNAME_M="$(uname -m)"
readonly UNAME_M

readonly CASA_SERVICES=(
    "casaos-gateway.service"
    "casaos.service" # must be the last one so update from UI can work
)

TARGET_ARCH=""
TMP_ROOT=/tmp/casaos-installer

upgradePath="/var/log/casaos"
upgradeFile="/var/log/casaos/upgrade.log"

if [ -f "$upgradePath" ]; then
    ${sudo_cmd} rm "$upgradePath"
fi

if [ ! -d "$upgradePath" ]; then
    ${sudo_cmd} mkdir -p "$upgradePath"
fi

if [ ! -f "$upgradeFile" ]; then
    ${sudo_cmd} touch "$upgradeFile"
fi

###############################################################################
# Helpers                                                                     #
###############################################################################

# $1 0:OK  1:FAILED  2:INFO  3:NOTICE — mirrors upstream so the UI's
# upgrade.log polling keeps working
Show() {
    if (($1 == 0)); then
        echo -e "- OK $2" | ${sudo_cmd} tee -a /var/log/casaos/upgrade.log
    elif (($1 == 1)); then
        echo -e "- FAILED $2" | ${sudo_cmd} tee -a /var/log/casaos/upgrade.log
        exit 1
    elif (($1 == 2)); then
        echo -e "- INFO $2" | ${sudo_cmd} tee -a /var/log/casaos/upgrade.log
    elif (($1 == 3)); then
        echo -e "- NOTICE $2" | ${sudo_cmd} tee -a /var/log/casaos/upgrade.log
    fi
}

###############################################################################
# FUNCTIONS                                                                   #
###############################################################################

Check_Dependency() {
    for cmd in wget tar systemctl; do
        if ! command -v "${cmd}" >/dev/null; then
            Show 1 "Missing required command: ${cmd}"
        fi
    done
}

Check_Arch() {
    case $UNAME_M in
    *aarch64*)
        TARGET_ARCH="arm64"
        ;;
    *64*)
        TARGET_ARCH="amd64"
        ;;
    *armv7*)
        TARGET_ARCH="arm-7"
        ;;
    *)
        Show 1 "Aborted, unsupported or unknown architecture: $UNAME_M"
        exit 1
        ;;
    esac
    Show 0 "Your hardware architecture is : $UNAME_M"

    # shortcut: version pins bump per release (docs/releasing.md); asset names
    # must match the releases byte-for-byte (arm-7, not armv7)
    readonly CASA_PACKAGES=(
        "https://github.com/Elephant-on-github/neo-casaos-gateway/releases/download/v0.4.10/linux-${TARGET_ARCH}-casaos-gateway-v0.4.10.tar.gz"
        "https://github.com/Elephant-on-github/neo-casaos/releases/download/v0.4.22/linux-${TARGET_ARCH}-casaos-v0.4.22.tar.gz"
        "https://github.com/Elephant-on-github/neo-casaos-ui/releases/download/v0.4.48/linux-all-casaos-v0.4.48.tar.gz"
    )
}

# Download and install the pinned neo components. Mechanics mirror upstream
# get.casaos.io/update: sysroot tarballs are overlaid onto /.
DownloadAndInstallCasaOS() {

    ${sudo_cmd} mkdir -p ${TMP_ROOT} || Show 1 "Failed to create temporary directory"
    TMP_DIR=$(${sudo_cmd} mktemp -d -p ${TMP_ROOT} || Show 1 "Failed to create temporary directory")

    pushd "${TMP_DIR}"

    for PACKAGE in "${CASA_PACKAGES[@]}"; do
        Show 2 "Downloading ${PACKAGE}..."
        ${sudo_cmd} wget -t 3 -q --show-progress -c "${PACKAGE}" || Show 1 "Failed to download package"
    done

    for PACKAGE_FILE in linux-*.tar.gz; do
        Show 2 "Extracting ${PACKAGE_FILE}..."
        ${sudo_cmd} tar zxf "${PACKAGE_FILE}" || Show 1 "Failed to extract package"
    done

    BUILD_DIR=$(realpath -e "${TMP_DIR}"/build || Show 1 "Failed to find build directory")

    popd

    MIGRATION_SCRIPT_DIR=$(realpath -e "${BUILD_DIR}"/scripts/migration/script.d || Show 1 "Failed to find migration script directory")

    for MIGRATION_SCRIPT in "${MIGRATION_SCRIPT_DIR}"/*.sh; do
        Show 2 "Running ${MIGRATION_SCRIPT}..."
        ${sudo_cmd} bash "${MIGRATION_SCRIPT}" || Show 1 "Failed to run migration script"
    done

    Show 2 "Installing CasaOS (neo)..."
    SYSROOT_DIR=$(realpath -e "${BUILD_DIR}"/sysroot || Show 1 "Failed to find sysroot directory")

    # Merge this release's file list into the existing manifest instead of
    # truncating it: we only ship 3 components, and the uninstall script must
    # keep tracking upstream-owned services' files.
    MANIFEST_FILE=/var/lib/casaos/manifest
    NEW_MANIFEST=$(${sudo_cmd} mktemp)
    find "${SYSROOT_DIR}" -type f | ${sudo_cmd} cut -c "${#SYSROOT_DIR}-" | ${sudo_cmd} cut -c 2- | ${sudo_cmd} tee "${NEW_MANIFEST}" >/dev/null || Show 1 "Failed to generate manifest"
    if [ -f "${MANIFEST_FILE}" ]; then
        ${sudo_cmd} sort -u "${MANIFEST_FILE}" "${NEW_MANIFEST}" -o "${MANIFEST_FILE}" || Show 1 "Failed to merge manifest"
        ${sudo_cmd} rm -f "${NEW_MANIFEST}"
    else
        ${sudo_cmd} mkdir -p "$(dirname "${MANIFEST_FILE}")"
        ${sudo_cmd} mv "${NEW_MANIFEST}" "${MANIFEST_FILE}"
    fi

    # Remove old UI files.
    ${sudo_cmd} rm -rf /var/lib/casaos/www/*

    ${sudo_cmd} cp -rf "${SYSROOT_DIR}"/* / || Show 1 "Failed to install CasaOS"

    SETUP_SCRIPT_DIR=$(realpath -e "${BUILD_DIR}"/scripts/setup/script.d || Show 1 "Failed to find setup script directory")

    for SETUP_SCRIPT in "${SETUP_SCRIPT_DIR}"/*.sh; do
        Show 2 "Running ${SETUP_SCRIPT}..."
        ${sudo_cmd} bash "${SETUP_SCRIPT}" || Show 1 "Failed to run setup script"
    done

    UI_EVENTS_REG_SCRIPT=/etc/casaos/start.d/register-ui-events.sh
    if [[ -f ${UI_EVENTS_REG_SCRIPT} ]]; then
        ${sudo_cmd} chmod +x ${UI_EVENTS_REG_SCRIPT}
    fi

    Show 0 "CasaOS upgrade successfully"
    for SERVICE in "${CASA_SERVICES[@]}"; do
        Show 2 "restart ${SERVICE}..."
        ${sudo_cmd} systemctl restart "${SERVICE}" || Show 3 "Service ${SERVICE} does not exist."
    done

}

###############################################################################
# Main                                                                        #
###############################################################################

Check_Dependency

Check_Arch

DownloadAndInstallCasaOS
