#!/usr/bin/env bash
# Yocto environment scripts commonly read optional variables before assigning
# defaults, so nounset (-u) is intentionally not enabled here.
set -eo pipefail

build_dir=${BUILD_DIR:-jenkins-build}
image=${IMAGE:-devel-image}
repository_root=$(git rev-parse --show-toplevel)
top_level_setup=$repository_root/setup.sh
[[ -f "$top_level_setup" ]] || {
    echo "Top-level setup script not found: $top_level_setup" >&2
    exit 2
}
[[ "$build_dir" == /* ]] || build_dir=$repository_root/$build_dir
export ALLOW_UPDATE=0
bash "$top_level_setup" "$build_dir"
# shellcheck disable=SC1090
source "$build_dir/setup.sh"

# This is a Jenkins-owned build directory. Recreate its overrides so changing
# job parameters cannot leave a previous MACHINE or test selection behind.
: > conf/auto.conf

# Keep downloads and sstate outside the workspace for reuse by OpenCGX jobs.
download_dir=${YOCTO_DOWNLOAD_DIR:-$HOME/downloads}
sstate_dir=${YOCTO_SSTATE_DIR:-$HOME/sstate-cache}
mkdir -p "$download_dir" "$sstate_dir"
{
    printf 'DL_DIR = "%s"\n' "$download_dir"
    printf 'SSTATE_DIR = "%s"\n' "$sstate_dir"
    printf 'TEST_RUNQEMUPARAMS = "slirp"'
} >> conf/auto.conf

set_machine() {
    [[ -z "$1" ]] || printf '\nMACHINE = "%s"\n' "$1" >> conf/auto.conf
}

initial_machine=${MACHINE:-}
if [[ -z "$initial_machine" ]]; then
    initial_machine=$(awk '
        {
            for (field = 1; field <= NF; field++) {
                if ($field ~ /^MACHINE@[^[:space:]\\]+$/) {
                    machine = $field
                    sub(/^MACHINE@/, "", machine)
                }
            }
        }
        END { print machine }
    ' "$top_level_setup")
fi
[[ -n "$initial_machine" ]] || {
    echo "No MACHINE parameter or MACHINE@ entry was found in $top_level_setup" >&2
    exit 2
}
set_machine "$initial_machine"
bitbake "$image"

if [[ "${QEMU_TESTS:-false}" == true ]]; then
    qemu_machine=${QEMU_MACHINE:-$initial_machine}
    if [[ "$initial_machine" != "$qemu_machine" ]]; then
        set_machine "$qemu_machine"
        bitbake "$image"
    fi
    {
        echo 'IMAGE_CLASSES += "testimage"'
        printf 'TEST_SUITES = "%s"\n' "${TEST_SUITES:-ping date df ssh scp python perl gi ptest parselogs logrotate connman systemd oe_syslog pam stap ldd xorg kernelmodule gcc buildcpio buildlzip buildgalculator dnf rpm opkg apt weston go rust}"
    } >> conf/auto.conf
    bitbake "$image" -c testimage
fi
