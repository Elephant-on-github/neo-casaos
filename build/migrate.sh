#!/usr/bin/bash
#
#           CasaOS (neo) Migration Script
#
#   GitHub: https://github.com/Elephant-on-github/neo-casaos
#   Issues: https://github.com/Elephant-on-github/neo-casaos/issues
#   Requires: bash, grep, sed, sort, curl, casaos (existing install)
#   GNU coreutils: sort -V, sed -i (no suffix arg). All stock targets are GNU.
#
#   This script moves an existing stock CasaOS install to the neo release
#   channel: it points CasaOS's update mechanism at the neo update script,
#   then installs the pinned neo components. Data and databases are
#   untouched; upstream-only services are left alone.
#   Usage:
#
#   	  curl -fsSL https://raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/build/migrate.sh | sudo bash
#
#   Rollback: run the official update (https://get.casaos.io/update), then
#   revert the UpdateUrl line in /etc/casaos/casaos.conf.
#
#   In automated environments, you may want to run as root.
#   If using curl, we recommend using the -fsSL flags.
#

export PATH=/usr/sbin:$PATH
set -e
set -o pipefail

###############################################################################
# GLOBALS                                                                     #
###############################################################################

((EUID)) && sudo_cmd="sudo"

readonly UPDATE_URL="https://raw.githubusercontent.com/Elephant-on-github/neo-casaos/main/build/update.sh"
readonly FORK_BASE="0.4.15"
readonly CONF=/etc/casaos/casaos.conf

###############################################################################
# Main                                                                        #
###############################################################################

# Preflight: this is a one-shot converter for EXISTING stock installs.
if [ ! -f "${CONF}" ]; then
    echo "FAILED: ${CONF} not found - this does not look like an existing CasaOS install." >&2
    exit 1
fi
if ! command -v casaos >/dev/null; then
    echo "FAILED: casaos binary not found on PATH - this does not look like an existing CasaOS install." >&2
    exit 1
fi

# Version guard: warn (never block) when stock is newer than the neo base.
STOCK="$(casaos -v 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)"
if [ -n "${STOCK}" ] && [ "$(printf '%s\n%s\n' "${FORK_BASE}" "${STOCK}" | sort -V | tail -n1)" != "${FORK_BASE}" ]; then
    echo "NOTICE: stock CasaOS ${STOCK} is newer than the neo base ${FORK_BASE}."
    echo "        Proceeding, but please report any issues to the neo fork."
fi

# Config flip BEFORE install: if the install fails, the next Update button
# press completes the migration through the neo update script (self-heal)
# instead of silently reverting to stock.
echo "- INFO Setting UpdateUrl to the neo update script..."
if grep -qE '^\s*UpdateUrl\s*=' "${CONF}"; then
    ${sudo_cmd} sed -i -E "s|^\s*UpdateUrl\s*=.*|UpdateUrl = ${UPDATE_URL}|" "${CONF}"
else
    ${sudo_cmd} sed -i "/^\[server\]/a UpdateUrl = ${UPDATE_URL}" "${CONF}"
fi

# The backend reads UpdateUrl at startup only: restart it so the running
# process already targets the neo channel even if the install below fails
# (that is what makes the next Update press self-heal).
echo "- INFO Restarting casaos service..."
${sudo_cmd} systemctl restart casaos.service

echo "- INFO Installing neo components (this can take a few minutes)..."
curl -fsSL "${UPDATE_URL}" | bash

echo ""
echo "Migration complete. CasaOS now runs neo builds and future updates"
echo "come from the neo release channel (UI -> Settings -> Update)."
echo "If anything looks wrong, see the rollback note in this script's header."
