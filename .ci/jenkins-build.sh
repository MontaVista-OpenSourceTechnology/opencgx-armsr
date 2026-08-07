#!/usr/bin/env bash
set -euo pipefail

build_dir=${BUILD_DIR:-jenkins-build}
image=${IMAGE:-core-image-minimal}
export ALLOW_UPDATE=0
bash setup.sh "$build_dir"
# shellcheck disable=SC1090
source "$build_dir/setup.sh"

# This is a Jenkins-owned build directory. Recreate its overrides so changing
# job parameters cannot leave a previous MACHINE or test selection behind.
: > conf/auto.conf

# Keep downloaded sources and shared-state artifacts outside the workspace so
# they survive workspace cleanup and can be reused by other OpenCGX jobs run by
# the same Jenkins user.
download_dir=${YOCTO_DOWNLOAD_DIR:-$HOME/downloads}
sstate_dir=${YOCTO_SSTATE_DIR:-$HOME/sstate-cache}
mkdir -p "$download_dir" "$sstate_dir"
{
    printf 'DL_DIR = "%s"\n' "$download_dir"
    printf 'SSTATE_DIR = "%s"\n' "$sstate_dir"
} >> conf/auto.conf

set_machine() {
    [[ -z "$1" ]] || printf '\nMACHINE = "%s"\n' "$1" >> conf/auto.conf
}

if [[ "${QEMU_TESTS:-false}" == true && -z "${QEMU_MACHINE:-}" ]]; then
    echo 'QEMU_MACHINE is required when QEMU_TESTS is enabled' >&2
    exit 2
fi

initial_machine=${MACHINE:-}
if [[ "${QEMU_TESTS:-false}" == true && -z "$initial_machine" ]]; then
    initial_machine=$QEMU_MACHINE
fi
set_machine "$initial_machine"
bitbake "$image"

if [[ "${QEMU_TESTS:-false}" == true ]]; then
    if [[ "$initial_machine" != "$QEMU_MACHINE" ]]; then
        set_machine "$QEMU_MACHINE"
        bitbake "$image"
    fi
    {
        echo 'IMAGE_CLASSES += "testimage"'
        printf 'TEST_SUITES = "%s"\n' "${TEST_SUITES:-ping ssh date df}"
    } >> conf/auto.conf
    bitbake "$image" -c testimage
fi
