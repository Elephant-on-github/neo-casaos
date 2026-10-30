#!/usr/bin/bash
#
#           CasaOS (neo) Update Script
#
#   GitHub: https://github.com/Elephant-on-github/neo-casaos
#   Issues: https://github.com/Elephant-on-github/neo-casaos/issues
#   Requires: bash, wget, tar, systemctl (GNU coreutils: realpath, cut, sort, mktemp -p)
#
#   This script updates the neo-owned CasaOS components (backend,
#   gateway, UI) to the versions in the remote manifest. Only the
#   components that are actually behind get downloaded, so a UI-only
#   release no longer pulls the backend/gateway tarballs.
#   Usage:
#
#   	  curl -fsSL https://raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/build/update.sh | sudo bash
#   	  # optional: limit to specific components
#   	  curl -fsSL .../update.sh | sudo bash -s -- ui
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

readonly MANIFEST_URL="https://raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/version.json"
readonly INSTALLED_FILE="/etc/casaos/installed.json"

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

# Components to update: command-line args override, default = all three.
if [ "$#" -gt 0 ]; then
    REQUESTED_COMPONENTS=("$@")
else
    REQUESTED_COMPONENTS=("backend" "gateway" "ui")
fi

###############################################################################
# Helpers                                                                     #
###############################################################################

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
}

# Fallback pins used only if the manifest cannot be fetched.
FALLBACK_BACKEND="v0.4.22"
FALLBACK_GATEWAY="v0.4.10"
FALLBACK_UI="v0.4.50"

# Fetch the remote manifest into $1 (file path). Returns 0 on success.
fetch_manifest() {
    local out="$1"
    if wget -t 3 -q -O "$out" "$MANIFEST_URL" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Extract a component version from the manifest file ($1) using python3.
# Prints the version (without leading v) or empty on failure.
manifest_version() {
    local file="$1"
    local comp="$2"
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json,sys
try:
    d=json.load(open('$file'))
    print(d.get('data',{}).get('components',{}).get('$comp',{}).get('version',''))
except Exception:
    print('')
" 2>/dev/null
    else
        # crude fallback: grep
        grep -o "\"$comp\"[^}]*\"version\"[^\"]*\"[^\"]*\"" "$file" | sed -E 's/.*\"version\"[^"]*\"([^\"]*)\".*/\1/'
    fi
}

# Read installed version for a component from the state file.
installed_version() {
    local comp="$1"
    if [ -f "$INSTALLED_FILE" ]; then
        if command -v python3 >/dev/null 2>&1; then
            python3 -c "
import json
try:
    d=json.load(open('$INSTALLED_FILE'))
    print(d.get('$comp',''))
except Exception:
    print('')
" 2>/dev/null
        fi
    fi
}

###############################################################################
# FUNCTIONS                                                                   #
###############################################################################

DownloadAndInstallCasaOS() {
    ${sudo_cmd} mkdir -p ${TMP_ROOT} || Show 1 "Failed to create temporary directory"
    TMP_DIR=$(${sudo_cmd} mktemp -d -p ${TMP_ROOT} || Show 1 "Failed to create temporary directory")

    pushd "${TMP_DIR}"

    # Fetch the manifest (single source of truth for latest versions).
    MANIFEST_FILE="${TMP_DIR}/version.json"
    if fetch_manifest "$MANIFEST_FILE"; then
        Show 0 "Manifest fetched"
    else
        Show 3 "Manifest fetch failed, falling back to pinned versions"
        MANIFEST_FILE=""
    fi

    # Resolve latest version per requested component.
    declare -A LATEST
    for comp in "${REQUESTED_COMPONENTS[@]}"; do
        v=""
        if [ -n "$MANIFEST_FILE" ]; then
            v="$(manifest_version "$MANIFEST_FILE" "$comp")"
        fi
        if [ -z "$v" ]; then
            case "$comp" in
                backend) v="${FALLBACK_BACKEND#v}" ;;
                gateway) v="${FALLBACK_GATEWAY#v}" ;;
                ui)      v="${FALLBACK_UI#v}" ;;
            esac
        fi
        LATEST[$comp]="$v"
    done

    # Determine which components actually need updating.
    declare -a TO_UPDATE=()
    for comp in "${REQUESTED_COMPONENTS[@]}"; do
        inst="$(installed_version "$comp")"
        # backend installed version is authoritative from the binary; prefer it
        # when the state file is missing/empty.
        if [ "$comp" = "backend" ] && [ -z "$inst" ]; then
            if command -v casaos >/dev/null 2>&1; then
                inst="$(casaos -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
            fi
        fi
        if [ -z "$inst" ] || [ "$inst" != "${LATEST[$comp]}" ]; then
            TO_UPDATE+=("$comp")
            Show 2 "Component $comp: installed=${inst:-unknown} -> ${LATEST[$comp]} (will update)"
        else
            Show 0 "Component $comp: already at ${inst}, skipping"
        fi
    done

    if [ "${#TO_UPDATE[@]}" -eq 0 ]; then
        Show 0 "All requested components are up to date"
        # still refresh the state file
        write_installed_state "${LATEST[@]}"
        popd
        return 0
    fi

    # Download only the components that need updating.
    for comp in "${TO_UPDATE[@]}"; do
        ver="${LATEST[$comp]}"
        case "$comp" in
            backend)
                url="https://github.com/Elephant-on-github/neo-casaos/releases/download/v${ver}/linux-${TARGET_ARCH}-casaos-v${ver}.tar.gz"
                ;;
            gateway)
                url="https://github.com/Elephant-on-github/neo-casaos-gateway/releases/download/v${ver}/linux-${TARGET_ARCH}-casaos-gateway-v${ver}.tar.gz"
                ;;
            ui)
                url="https://github.com/Elephant-on-github/neo-casaos-ui/releases/download/v${ver}/linux-all-casaos-v${ver}.tar.gz"
                ;;
            *)
                Show 1 "Unknown component: $comp"
                ;;
        esac
        Show 2 "Downloading $comp ($url)..."
        ${sudo_cmd} wget -t 3 -q --show-progress -c "$url" || Show 1 "Failed to download $comp"
    done

    for PACKAGE_FILE in linux-*.tar.gz; do
        [ -e "$PACKAGE_FILE" ] || continue
        Show 2 "Extracting ${PACKAGE_FILE}..."
        ${sudo_cmd} tar zxf "${PACKAGE_FILE}" || Show 1 "Failed to extract package"
    done

    BUILD_DIR=$(realpath -e "${TMP_DIR}"/build || Show 1 "Failed to find build directory")

    popd

    MIGRATION_SCRIPT_DIR=$(realpath -e "${BUILD_DIR}"/scripts/migration/script.d || Show 1 "Failed to find migration script directory")

    for MIGRATION_SCRIPT in "${MIGRATION_SCRIPT_DIR}"/*.sh; do
        [ -e "$MIGRATION_SCRIPT" ] || continue
        Show 2 "Running ${MIGRATION_SCRIPT}..."
        ${sudo_cmd} bash "${MIGRATION_SCRIPT}" || Show 1 "Failed to run migration script"
    done

    Show 2 "Installing CasaOS (neo)..."
    SYSROOT_DIR=$(realpath -e "${BUILD_DIR}"/sysroot || Show 1 "Failed to find sysroot directory")

    MANIFEST_FILE_LOCAL=/var/lib/casaos/manifest
    NEW_MANIFEST=$(${sudo_cmd} mktemp)
    find "${SYSROOT_DIR}" -type f | ${sudo_cmd} cut -c "${#SYSROOT_DIR}-" | ${sudo_cmd} cut -c 2- | ${sudo_cmd} tee "${NEW_MANIFEST}" >/dev/null || Show 1 "Failed to generate manifest"
    if [ -f "${MANIFEST_FILE_LOCAL}" ]; then
        ${sudo_cmd} sort -u "${MANIFEST_FILE_LOCAL}" "${NEW_MANIFEST}" -o "${MANIFEST_FILE_LOCAL}" || Show 1 "Failed to merge manifest"
        ${sudo_cmd} rm -f "${NEW_MANIFEST}"
    else
        ${sudo_cmd} mkdir -p "$(dirname "${MANIFEST_FILE_LOCAL}")"
        ${sudo_cmd} mv "${NEW_MANIFEST}" "${MANIFEST_FILE_LOCAL}"
    fi

    # Remove old UI files only if UI was updated.
    if printf '%s\n' "${TO_UPDATE[@]}" | grep -qx "ui"; then
        ${sudo_cmd} rm -rf /var/lib/casaos/www/*
    fi

    ${sudo_cmd} cp -rf "${SYSROOT_DIR}"/* / || Show 1 "Failed to install CasaOS"

    SETUP_SCRIPT_DIR=$(realpath -e "${BUILD_DIR}"/scripts/setup/script.d || Show 1 "Failed to find setup script directory")

    for SETUP_SCRIPT in "${SETUP_SCRIPT_DIR}"/*.sh; do
        [ -e "$SETUP_SCRIPT" ] || continue
        Show 2 "Running ${SETUP_SCRIPT}..."
        ${sudo_cmd} bash "${SETUP_SCRIPT}" || Show 1 "Failed to run setup script"
    done

    UI_EVENTS_REG_SCRIPT=/etc/casaos/start.d/register-ui-events.sh
    if [[ -f ${UI_EVENTS_REG_SCRIPT} ]]; then
        ${sudo_cmd} chmod +x ${UI_EVENTS_REG_SCRIPT}
    fi

    # Write the installed-versions state file (all three, with latest known).
    write_installed_state

    # Restart services only if a binary component changed.
    if printf '%s\n' "${TO_UPDATE[@]}" | grep -qE '^(backend|gateway)$'; then
        for SERVICE in "${CASA_SERVICES[@]}"; do
            Show 2 "restart ${SERVICE}..."
            ${sudo_cmd} systemctl restart "${SERVICE}" || Show 3 "Service ${SERVICE} does not exist."
        done
    else
        Show 0 "UI-only update: no service restart needed, reload the browser to apply"
    fi

    Show 0 "CasaOS upgrade successfully"
}

write_installed_state() {
    # Record latest known versions (from manifest if available, else fallback).
    local b g u
    b="${LATEST[backend]:-${FALLBACK_BACKEND#v}}"
    g="${LATEST[gateway]:-${FALLBACK_GATEWAY#v}}"
    u="${LATEST[ui]:-${FALLBACK_UI#v}}"
    ${sudo_cmd} mkdir -p "$(dirname "$INSTALLED_FILE")"
    printf '{"backend":"%s","gateway":"%s","ui":"%s"}\n' "$b" "$g" "$u" | ${sudo_cmd} tee "$INSTALLED_FILE" >/dev/null
}

###############################################################################
# Main                                                                        #
###############################################################################

Check_Dependency
Check_Arch

DownloadAndInstallCasaOS