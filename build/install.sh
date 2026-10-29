#!/usr/bin/bash
#
#           CasaOS (neo) Installer Script
#
#   GitHub: https://github.com/Elephant-on-github/neo-casaos
#   Issues: https://github.com/Elephant-on-github/neo-casaos/issues
#   Requires: bash, wget, tar, systemctl, curl
#
#   This script installs CasaOS (neo) to your system.
#   Usage:
#
#   	  curl -fsSL https://raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/build/install.sh | sudo bash
#
#   In automated environments, you may want to run as root.
#   If using curl, we recommend using the -fsSL flags.
#
#   This only works on Linux systems.
#

export PATH=/usr/sbin:$PATH
export DEBIAN_FRONTEND=noninteractive

set -e
set -o pipefail

###############################################################################
# GLOBALS                                                                     #
###############################################################################

((EUID)) && sudo_cmd="sudo"

readonly MINIMUM_DISK_SIZE_GB="5"
readonly MINIMUM_MEMORY="400"
readonly MINIMUM_DOCKER_VERSION="20"

readonly CASA_DEPANDS_PACKAGE=('wget' 'curl' 'smartmontools' 'parted' 'ntfs-3g' 'net-tools' 'udevil' 'samba' 'cifs-utils' 'mergerfs' 'unzip')
readonly CASA_DEPANDS_COMMAND=('wget' 'curl' 'smartctl' 'parted' 'ntfs-3g' 'netstat' 'udevil' 'smbd' 'mount.cifs' 'mount.mergerfs' 'unzip')

PHYSICAL_MEMORY=$(LC_ALL=C free -m | awk '/Mem:/ { print $2 }')
readonly PHYSICAL_MEMORY

FREE_DISK_BYTES=$(LC_ALL=C df -P / | tail -n 1 | awk '{print $4}')
readonly FREE_DISK_BYTES

readonly FREE_DISK_GB=$((FREE_DISK_BYTES / 1024 / 1024))

# shellcheck disable=SC1091
source /etc/os-release

LSB_DIST=$( ([ -n "${ID_LIKE}" ] && echo "${ID_LIKE}") || ([ -n "${ID}" ] && echo "${ID}") )
readonly LSB_DIST

UNAME_M="$(uname -m)"
readonly UNAME_M

UNAME_U="$(uname -s)"
readonly UNAME_U

readonly CASA_CONF_PATH=/etc/casaos/casaos.conf
readonly UPDATE_URL="https://raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/build/update.sh"
readonly CASA_UNINSTALL_URL="https://raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/build/uninstall.sh"
readonly CASA_UNINSTALL_PATH=/usr/bin/casaos-uninstall

TARGET_ARCH=""
TMP_ROOT=/tmp/casaos-installer
TMP_DIR=""

readonly UDEVIL_CONF_PATH=/etc/udevil/udevil.conf
readonly DEVMON_CONF_PATH=/etc/conf.d/devmon

readonly COLOUR_RESET='\e[0m'
readonly aCOLOUR=(
    '\e[38;5;154m'
    '\e[1m'
    '\e[90m'
    '\e[91m'
    '\e[33m'
)

# PACKAGE LIST — service order matters (casaos.service must be last so the
# UI update flow keeps working across the restart).
# neo components come from this fork; the remaining CasaOS services are not
# forked yet and are installed from upstream releases.
readonly CASA_SERVICES=(
    "casaos-gateway.service"
    "casaos-message-bus.service"
    "casaos-user-service.service"
    "casaos-local-storage.service"
    "casaos-app-management.service"
    "rclone.service"
    "casaos.service"
)

trap 'onCtrlC' INT
onCtrlC() {
    echo -e "${COLOUR_RESET}"
    exit 1
}

###############################################################################
# Helpers                                                                     #
###############################################################################

Show() {
    if (($1 == 0)); then
        echo -e "${aCOLOUR[2]}[${COLOUR_RESET}${aCOLOUR[0]}  OK  ${COLOUR_RESET}${aCOLOUR[2]}]${COLOUR_RESET} $2"
    elif (($1 == 1)); then
        echo -e "${aCOLOUR[2]}[${COLOUR_RESET}${aCOLOUR[3]}FAILED${COLOUR_RESET}${aCOLOUR[2]}]${COLOUR_RESET} $2"
        exit 1
    elif (($1 == 2)); then
        echo -e "${aCOLOUR[2]}[${COLOUR_RESET}${aCOLOUR[0]} INFO  ${COLOUR_RESET}${aCOLOUR[2]}]${COLOUR_RESET} $2"
    elif (($1 == 3)); then
        echo -e "${aCOLOUR[2]}[${COLOUR_RESET}${aCOLOUR[4]}NOTICE${COLOUR_RESET}${aCOLOUR[2]}]${COLOUR_RESET} $2"
    fi
}

GreyStart() {
    echo -e "${aCOLOUR[2]}\c"
}

ColorReset() {
    echo -e "${COLOUR_RESET}\c"
}

###############################################################################
# FUNCTIONS                                                                   #
###############################################################################

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
        "${NEO_REPO}/neo-casaos-gateway/releases/download/v0.4.10/linux-${TARGET_ARCH}-casaos-gateway-v0.4.10.tar.gz"
        "${NEO_REPO}/neo-casaos/releases/download/v0.4.22/linux-${TARGET_ARCH}-casaos-v0.4.22.tar.gz"
        "${NEO_REPO}/neo-casaos-ui/releases/download/v0.4.49/linux-all-casaos-v0.4.49.tar.gz"
        "${UPSTREAM_REPO}/CasaOS-MessageBus/releases/download/v0.4.4-3-alpha2/linux-${TARGET_ARCH}-casaos-message-bus-v0.4.4-3-alpha2.tar.gz"
        "${UPSTREAM_REPO}/CasaOS-UserService/releases/download/v0.4.8/linux-${TARGET_ARCH}-casaos-user-service-v0.4.8.tar.gz"
        "${UPSTREAM_REPO}/CasaOS-LocalStorage/releases/download/v0.4.4/linux-${TARGET_ARCH}-casaos-local-storage-v0.4.4.tar.gz"
        "${UPSTREAM_REPO}/CasaOS-AppManagement/releases/download/v0.4.10-alpha2/linux-${TARGET_ARCH}-casaos-app-management-v0.4.10-alpha2.tar.gz"
        "${UPSTREAM_REPO}/CasaOS-CLI/releases/download/v0.4.4-3-alpha1/linux-${TARGET_ARCH}-casaos-cli-v0.4.4-3-alpha1.tar.gz"
        "${UPSTREAM_REPO}/CasaOS-AppStore/releases/download/v0.4.5/linux-all-appstore-v0.4.5.tar.gz"
    )
}

Check_OS() {
    if [[ $UNAME_U == *Linux* ]]; then
        Show 0 "Your System is : $UNAME_U"
    else
        Show 1 "This script is only for Linux."
        exit 1
    fi
}

Check_Distribution() {
    case $LSB_DIST in
    *debian*) ;;
    *ubuntu*) ;;
    *raspbian*) ;;
    *openwrt*)
        Show 1 "Aborted, OpenWrt is not supported."
        exit 1
        ;;
    *alpine*)
        Show 1 "Aborted, Alpine is not supported."
        exit 1
        ;;
    *trisquel*) ;;
    *)
        Show 3 "We have not tested this system and the installation may fail."
        ;;
    esac
    Show 0 "Your Linux Distribution is : $LSB_DIST"
}

Check_Memory() {
    if [[ "${PHYSICAL_MEMORY}" -lt "${MINIMUM_MEMORY}" ]]; then
        Show 1 "requires at least ${MINIMUM_MEMORY}MB physical memory."
        exit 1
    fi
    Show 0 "Memory capacity check passed."
}

Check_Disk() {
    if [[ "${FREE_DISK_GB}" -lt "${MINIMUM_DISK_SIZE_GB}" ]]; then
        Show 1 "Recommended free disk space is greater than ${MINIMUM_DISK_SIZE_GB}GB, current free disk space is ${FREE_DISK_GB}GB."
        exit 1
    fi
    Show 0 "Disk capacity check passed."
}

Update_Package_Resource() {
    GreyStart
    if [ -x "$(command -v apk)" ]; then
        ${sudo_cmd} apk update
    elif [ -x "$(command -v apt-get)" ]; then
        ${sudo_cmd} apt-get update -qq
    elif [ -x "$(command -v dnf)" ]; then
        ${sudo_cmd} dnf check-update
    elif [ -x "$(command -v zypper)" ]; then
        ${sudo_cmd} zypper refresh
    elif [ -x "$(command -v yum)" ]; then
        ${sudo_cmd} yum update
    fi
    ColorReset
}

Install_Depends() {
    for ((i = 0; i < ${#CASA_DEPANDS_COMMAND[@]}; i++)); do
        cmd=${CASA_DEPANDS_COMMAND[i]}
        if ! command -v "${cmd}" >/dev/null; then
            packagesNeeded=${CASA_DEPANDS_PACKAGE[i]}
            Show 2 "Installing the necessary dependency: ${packagesNeeded}"
            GreyStart
            if [ -x "$(command -v apk)" ]; then
                ${sudo_cmd} apk add --no-cache "${packagesNeeded}"
            elif [ -x "$(command -v apt-get)" ]; then
                ${sudo_cmd} apt-get -y -qq install "${packagesNeeded}" --no-upgrade
            elif [ -x "$(command -v dnf)" ]; then
                ${sudo_cmd} dnf install "${packagesNeeded}"
            elif [ -x "$(command -v zypper)" ]; then
                ${sudo_cmd} zypper install "${packagesNeeded}"
            elif [ -x "$(command -v yum)" ]; then
                ${sudo_cmd} yum install -y "${packagesNeeded}"
            elif [ -x "$(command -v pacman)" ]; then
                ${sudo_cmd} pacman -S --noconfirm "${packagesNeeded}"
            else
                Show 1 "Package manager not found. You must manually install: ${packagesNeeded}"
            fi
            ColorReset
        fi
    done
}

Check_Dependency_Installation() {
    for ((i = 0; i < ${#CASA_DEPANDS_COMMAND[@]}; i++)); do
        cmd=${CASA_DEPANDS_COMMAND[i]}
        if ! command -v "${cmd}" >/dev/null; then
            Show 1 "Dependency installation failed, please install ${CASA_DEPANDS_PACKAGE[i]} manually and retry."
            exit 1
        fi
    done
}

Install_Docker() {
    Show 2 "Installing Docker..."
    GreyStart
    ${sudo_cmd} curl -fsSL https://get.docker.com | bash
    ColorReset
    Show 0 "Docker installed."
}

Check_Docker_Install() {
    if [ -x "$(command -v docker)" ]; then
        Docker_Version=$(${sudo_cmd} docker version --format '{{.Server.Version}}' 2>/dev/null || echo "0")
        if [[ "${Docker_Version:0:2}" -lt "${MINIMUM_DOCKER_VERSION}" ]]; then
            Show 1 "Recommended minimum Docker version is ${MINIMUM_DOCKER_VERSION}.xx.xx, current is ${Docker_Version}. Please upgrade Docker and retry."
            exit 1
        fi
        Show 0 "Docker version is ${Docker_Version}."
    else
        Install_Docker
    fi
}

Check_Docker_Running() {
    for ((i = 1; i <= 3; i++)); do
        sleep 3
        if ! ${sudo_cmd} systemctl is-active --quiet docker; then
            ${sudo_cmd} systemctl start docker
        else
            break
        fi
    done
}

Apply_Docker_API_Override() {
    local override_dir="/etc/systemd/system/docker.service.d"
    local override_file="${override_dir}/override.conf"

    ${sudo_cmd} mkdir -p "${override_dir}" || Show 3 "Failed to create ${override_dir} (non-fatal)."

    ${sudo_cmd} tee "${override_file}" >/dev/null <<'EOF'
[Service]
Environment=DOCKER_MIN_API_VERSION=1.24
EOF

    ${sudo_cmd} systemctl daemon-reload || Show 3 "systemd daemon-reload failed (non-fatal)."
    ${sudo_cmd} systemctl restart docker || Show 3 "Failed to restart Docker after API override (non-fatal)."
}

Install_Rclone() {
    Show 2 "Installing Rclone..."
    if [ -x "$(command -v rclone)" ]; then
        Show 3 "Rclone is already installed, keeping it."
    else
        ${sudo_cmd} wget -qO ./install.sh https://rclone.org/install.sh
        ${sudo_cmd} chmod +x ./install.sh
        ${sudo_cmd} ./install.sh || {
            Show 1 "Rclone installation failed, please try again manually."
            ${sudo_cmd} rm -rf install.sh
            exit 1
        }
        ${sudo_cmd} rm -rf install.sh
    fi
    ${sudo_cmd} systemctl enable rclone || Show 3 "Service rclone does not exist."
    Show 0 "Rclone installed."
}

Configuration_Addons() {
    Show 2 "Configuring CasaOS addons..."
    if [[ -f ${UDEVIL_CONF_PATH} ]]; then
        USERNAME=devmon
        id "${USERNAME}" &>/dev/null || {
            ${sudo_cmd} useradd -M -u 300 "${USERNAME}"
            ${sudo_cmd} usermod -L "${USERNAME}"
        }

        ${sudo_cmd} sed -i '/exfat/s/, nonempty//g' "${UDEVIL_CONF_PATH}"
        ${sudo_cmd} sed -i '/default_options/s/, noexec//g' "${UDEVIL_CONF_PATH}"
        ${sudo_cmd} sed -i '/^ARGS/cARGS="--mount-options nosuid,nodev,noatime --ignore-label EFI"' "${DEVMON_CONF_PATH}"

        ${sudo_cmd} systemctl enable devmon@devmon
        ${sudo_cmd} systemctl start devmon@devmon
    fi
    Show 0 "Addons configured."
}

# Point the update channel at neo so the UI's Upgrade button pulls neo releases.
Set_Neo_Update_Channel() {
    if [ ! -f "${CASA_CONF_PATH}" ]; then
        Show 3 "${CASA_CONF_PATH} not found, skipping update channel setup."
        return
    fi
    if grep -qE '^\s*UpdateUrl\s*=' "${CASA_CONF_PATH}"; then
        ${sudo_cmd} sed -i -E "s|^\s*UpdateUrl\s*=.*|UpdateUrl = ${UPDATE_URL}|" "${CASA_CONF_PATH}"
    else
        ${sudo_cmd} sed -i "/^\[server\]/a UpdateUrl = ${UPDATE_URL}" "${CASA_CONF_PATH}"
    fi
    Show 0 "Update channel set to neo."
}

Install_Uninstall_Script() {
    # The uninstall script is vendored in this repo (build/uninstall.sh) so it
    # cannot rot when upstream moves on, and it reads the manifest we write.
    ${sudo_cmd} curl -fsSLk "${CASA_UNINSTALL_URL}" >"${TMP_DIR}/casaos-uninstall" || {
        Show 3 "Failed to download the uninstall script, skipping."
        return
    }
    ${sudo_cmd} cp -rf "${TMP_DIR}/casaos-uninstall" "${CASA_UNINSTALL_PATH}" || {
        Show 3 "Failed to install the uninstall script, skipping."
        return
    }
    ${sudo_cmd} chmod +x "${CASA_UNINSTALL_PATH}"
    Show 0 "Uninstall script installed (${CASA_UNINSTALL_PATH})."
}

DownloadAndInstallCasaOS() {
    ${sudo_cmd} rm -rf "${TMP_ROOT}"
    ${sudo_cmd} mkdir -p "${TMP_ROOT}" || Show 1 "Failed to create temporary directory"
    TMP_DIR=$(${sudo_cmd} mktemp -d -p "${TMP_ROOT}" || Show 1 "Failed to create temporary directory")

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

    for SERVICE in "${CASA_SERVICES[@]}"; do
        if ${sudo_cmd} systemctl --quiet is-active "${SERVICE}"; then
            Show 2 "Stopping ${SERVICE}..."
            ${sudo_cmd} systemctl stop "${SERVICE}" || Show 3 "Service ${SERVICE} does not exist."
        fi
    done

    MIGRATION_SCRIPT_DIR=$(realpath -e "${BUILD_DIR}"/scripts/migration/script.d || Show 1 "Failed to find migration script directory")
    for MIGRATION_SCRIPT in "${MIGRATION_SCRIPT_DIR}"/*.sh; do
        Show 2 "Running ${MIGRATION_SCRIPT}..."
        ${sudo_cmd} bash "${MIGRATION_SCRIPT}" || Show 1 "Failed to run migration script"
    done

    Show 2 "Installing CasaOS (neo)..."
    SYSROOT_DIR=$(realpath -e "${BUILD_DIR}"/sysroot || Show 1 "Failed to find sysroot directory")

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

    ${sudo_cmd} cp -rf "${SYSROOT_DIR}"/* / || Show 1 "Failed to install CasaOS"

    SETUP_SCRIPT_DIR=$(realpath -e "${BUILD_DIR}"/scripts/setup/script.d || Show 1 "Failed to find setup script directory")
    for SETUP_SCRIPT in "${SETUP_SCRIPT_DIR}"/*.sh; do
        Show 2 "Running ${SETUP_SCRIPT}..."
        ${sudo_cmd} bash "${SETUP_SCRIPT}" || Show 1 "Failed to run setup script"
    done

    UI_EVENTS_REG_SCRIPT=/etc/casaos/start.d/register-ui-events.sh
    if [[ -f ${UI_EVENTS_REG_SCRIPT} ]]; then
        ${sudo_cmd} chmod +x "${UI_EVENTS_REG_SCRIPT}"
    fi

    Set_Neo_Update_Channel

    Install_Uninstall_Script

    Install_Rclone

    for SERVICE in "${CASA_SERVICES[@]}"; do
        Show 2 "Starting ${SERVICE}..."
        ${sudo_cmd} systemctl start "${SERVICE}" || Show 3 "Service ${SERVICE} does not exist."
    done
}

Clean_Temp_Files() {
    if [ -n "${TMP_DIR}" ]; then
        ${sudo_cmd} rm -rf "${TMP_DIR}" || Show 3 "Failed to clean temporary files"
    fi
}

Check_Service_status() {
    for SERVICE in "${CASA_SERVICES[@]}"; do
        if [[ $(${sudo_cmd} systemctl is-active "${SERVICE}") == "active" ]]; then
            Show 0 "${SERVICE} is running."
        else
            Show 3 "${SERVICE} is not running."
        fi
    done
}

Get_IPs() {
    PORT=$(${sudo_cmd} cat "${CASA_CONF_PATH}" 2>/dev/null | grep -i 'HttpPort' | awk -F= '{print $2}' | tr -d ' ')
    [ -z "${PORT}" ] && PORT="80"
    ALL_NIC=""
    for NIC_PATH in /sys/class/net/*; do
        NIC=$(basename "${NIC_PATH}")
        [ -e "/sys/devices/virtual/net/${NIC}" ] && continue
        ALL_NIC="${ALL_NIC} ${NIC}"
    done
    for NIC in ${ALL_NIC}; do
        IP=$(${sudo_cmd} ifconfig "${NIC}" 2>/dev/null | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | sed -e 's/addr://g')
        if [[ -n $IP ]]; then
            if [[ "$PORT" == "80" ]]; then
                echo -e " ${aCOLOUR[0]}-${COLOUR_RESET} http://$IP (${NIC})"
            else
                echo -e " ${aCOLOUR[0]}-${COLOUR_RESET} http://$IP:$PORT (${NIC})"
            fi
        fi
    done
}

Welcome_Banner() {
    CASA_TAG=$(casaos -v 2>/dev/null || echo "neo")

    echo -e "${aCOLOUR[0]}─────────────────────────────────────────────────────${COLOUR_RESET}"
    echo -e " ${aCOLOUR[1]}CasaOS (neo) ${CASA_TAG} is running at${COLOUR_RESET}${aCOLOUR[4]}:${COLOUR_RESET}"
    echo -e "${aCOLOUR[0]}─────────────────────────────────────────────────────${COLOUR_RESET}"
    Get_IPs
    echo -e " Open your browser and visit the address above."
    echo -e "${aCOLOUR[0]}─────────────────────────────────────────────────────${COLOUR_RESET}"
    echo -e " ${aCOLOUR[2]}Repository  : https://github.com/Elephant-on-github/neo-casaos"
    echo -e " ${aCOLOUR[2]}Issues      : https://github.com/Elephant-on-github/neo-casaos/issues"
    echo -e " ${aCOLOUR[2]}Updates     : Settings -> Update in the web UI"
    echo -e "${aCOLOUR[0]}─────────────────────────────────────────────────────${COLOUR_RESET}"
}

###############################################################################
# Main                                                                        #
###############################################################################

# Step 0: Release sources
NEO_REPO="https://github.com/Elephant-on-github"
UPSTREAM_REPO="https://github.com/IceWhaleTech"

# Step 1: Check ARCH
Check_Arch

# Step 2: Check OS
Check_OS

# Step 3: Check Distribution
Check_Distribution

# Step 4: Check System Requirements
Check_Memory
Check_Disk

# Step 5: Install Dependencies
Update_Package_Resource
Install_Depends
Check_Dependency_Installation

# Step 6: Check And Install Docker
Check_Docker_Install
Apply_Docker_API_Override
Check_Docker_Running

# Step 7: Configuration Addons
Configuration_Addons

# Step 8: Download And Install CasaOS
DownloadAndInstallCasaOS

# Step 9: Check Service Status
Check_Service_status

# Step 10: Clean up and show welcome banner
Clean_Temp_Files
Welcome_Banner
