#!/usr/bin/env bash
#
# build_qemu.sh
#
# Install QEMU and its dependencies.
#

# Echo commands
set -o xtrace

# Exit on error to stop unexpected errors
set -o errexit

function usage {
    echo "$0 - Install QEMU from tar releases."
    echo ""
    echo "Usage: $0 <QEMU_VERSION>"
    echo ""
    echo "Example: $0 2.1.0"
    exit 1
}

# Keep track of the current directory
TOOLS_DIR=$(cd $(dirname "$0") && pwd)
TOP_DIR=$(cd $TOOLS_DIR/..; pwd)

# Import common functions and variables
source $TOP_DIR/functions
source $TOP_DIR/stackrc

# Find the cache dir
FILES=$TOP_DIR/files

if [[ -z "$1" ]]; then
    usage
fi

echo "Installing QEMU $1"

# If these values are not user defined, we use official links
QEMU_URL_BASE=${QEMU_URL_BASE:-http://wiki.qemu-project.org/download/}

# QEMU is released as .tar.bz2, libvirt uses tar.gz
QEMU_FILE=qemu-"$1".tar.bz2
QEMU_DIR="$FILES"/qemu-"$1"

QEMU_URL="$QEMU_URL_BASE""$QEMU_FILE"

echo "Installing QEMU dependencies"
if is_ubuntu; then
    sudo apt-get build-dep qemu -y
elif is_fedora || is_suse; then
    sudo yum-builddep qemu -y
fi
if [[ ! -f "$QEMU_DIR/`uname -m`-softmmu/qemu-system-`uname -m`" ]]; then
    echo "Compiling QEMU"
    wget -N "$QEMU_URL" -P "$FILES"
    tar -xf "$FILES"/"$QEMU_FILE" -C "$FILES"
    cd "$QEMU_DIR"
    ./configure --target-list=`uname -m`-softmmu --prefix="$DEST"
    make -j"$(nproc)"
    sudo make install
else
    echo "QEMU version $1 binary found in $QEMU_DIR, skipping compilation."
fi
