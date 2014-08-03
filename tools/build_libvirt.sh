#!/usr/bin/env bash
#
# build_libvirt.sh
#
# Install libvirt and its dependencies.
#

# Echo commands
set -o xtrace

# Exit on error to stop unexpected errors
set -o errexit

function usage {
    echo "$0 - Install libvirt from tar releases."
    echo ""
    echo "Usage: $0 <LIBVIRT_VERSION>"
    echo ""
    echo "Example: $0 1.2.7"
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

echo "Installing libvirt $1"

# If these values are not user defined, we use official links
LIBVIRT_URL_BASE=${LIBVIRT_URL_BASE:-http://libvirt.org/sources/}

# QEMU is released as .tar.bz2, libvirt uses tar.gz
LIBVIRT_FILE=libvirt-"$1".tar.gz
LIBVIRT_DIR="$FILES"/libvirt-"$1"

LIBVIRT_URL="$LIBVIRT_URL_BASE""$LIBVIRT_FILE"

echo "Installing libvirt dependencies"
if is_ubuntu; then
    sudo apt-get build-dep libvirt -y
    install_package python-guestfs
elif is_fedora || is_suse; then
    sudo yum-builddep libvirt -y
    install_package python-libguestfs
fi
if [[ ! -f  "$LIBVIRT_DIR"/daemon/libvirtd ]]; then
    echo "Compiling libvirt"
    wget -N "$LIBVIRT_URL" -P "$FILES"
    tar -xf "$FILES"/"$LIBVIRT_FILE" -C "$FILES"
    cd "$LIBVIRT_DIR"
    ./configure --prefix="$DEST" --localstatedir=/var --libdir="$DEST"/lib --sysconfdir=/etc
    make -j"$(nproc)"
    echo "Installing libvirt"
    sudo make install
    if is_ubuntu; then
        if [[ ! -f /etc/init/libvirtd.conf ]]; then
            sudo cp daemon/libvirtd.upstart /etc/init/libvirtd.conf
            sudo sed -i "s/\/usr\/sbin/"$(echo $LIBVIRT_DIR | sed 's/\//\\\//g')"\/daemon/g" /etc/init/libvirtd.conf
        fi
    elif is_fedora; then
        if [[ ! -f /etc/init.d/libvirtd ]]; then
            sudo cp daemon/libvirtd.init /etc/init.d/libvirtd
        fi
    fi
    if [[ ! -f /usr/share/polkit-1/actions/org.libvirt.policy ]]; then
        sudo cp daemon/libvirtd.policy /usr/share/polkit-1/actions/org.libvirt.policy
    fi
else
    echo "libvirtd version $1 binary found in $LIBVIRT_DIR, skipping compilation."
fi
