#!/usr/bin/env bash
#
# build_qemu_libvirt.sh
#
# Install QEMU, libvirt and their dependencies.
#

# Echo commands
set -o xtrace

# Exit on error to stop unexpected errors
set -o errexit

function usage {
    echo "$0 - Install QEMU, libvirt and their dependencies from tar releases."
    echo ""
    echo "Usage: $0 <QEMU_VERSION> <LIBVIRT_VERSION>"
    echo ""
    echo "Example: $0 2.1.0 1.2.7"
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

if [[ -z "$2" ]]; then
    usage
fi

# If these values are not user defined, we use official links
QEMU_URL_BASE=${QEMU_URL_BASE:-http://wiki.qemu-project.org/download/}
LIBVIRT_URL_BASE=${LIBVIRT_URL_BASE:-http://libvirt.org/sources/}

# QEMU is released as .tar.bz2, libvirt uses tar.gz
QEMU_FILE=qemu-"$1".tar.bz2
QEMU_DIR="$FILES"/qemu-"$1"
LIBVIRT_FILE=libvirt-"$2".tar.gz
LIBVIRT_DIR="$FILES"/libvirt-"$2"

QEMU_URL="$QEMU_URL_BASE""$QEMU_FILE"
LIBVIRT_URL="$LIBVIRT_URL_BASE""$LIBVIRT_FILE"

# Performance optimization for make
N_CORES=$(cat /proc/cpuinfo | grep cores -m 1 | awk -F " " '{print $4}')

echo "Installing QEMU dependencies"
if is_ubuntu; then
    sudo apt-get build-dep qemu -y
elif is_fedora || is_suse; then
    sudo yum-builddep qemu -y
fi
if [[ ! -d "$QEMU_DIR" ]]; then
    echo "Compiling QEMU from sources"
    wget -N "$QEMU_URL" -P "$FILES"
    tar -xf "$FILES"/"$QEMU_FILE" -C "$FILES"
    cd "$QEMU_DIR"
    ./configure --target-list=`uname -m`-softmmu --prefix="$DEST"
    make -j"$N_CORES"
    sudo make install
else
    echo "QEMU directory found, skipping compilation."
fi

echo "Installing libvirt dependencies"
if is_ubuntu; then
    sudo apt-get build-dep libvirt -y
elif is_fedora || is_suse; then
    sudo yum-builddep libvirt -y
fi
if [[ ! -d  "$LIBVIRT_DIR" ]]; then
    echo "Compiling libvirt from sources"
    wget -N "$LIBVIRT_URL" -P "$FILES"
    tar -xf "$FILES"/"$LIBVIRT_FILE" -C "$FILES"
    cd "$LIBVIRT_DIR"
    ./configure --prefix="$DEST" --localstatedir=/var --libdir="$DEST"/lib --sysconfdir=/etc
    make -j"$N_CORES"
    echo "Installing libvirt"
    sudo make install
    if [[ ! -f /etc/init/libvirtd.conf ]]; then
        sudo cp daemon/libvirtd.upstart /etc/init/libvirtd.conf
        sudo sed -i "s/\/usr\/sbin/"$(echo $LIBVIRT_DIR | sed 's/\//\\\//g')"\/daemon/g" /etc/init/libvirtd.conf
    fi
    if [[ ! -f /usr/share/polkit-1/actions/org.libvirt.policy ]]; then
        sudo cp daemon/libvirtd.policy /usr/share/polkit-1/actions/org.libvirt.policy
    fi
else
    echo "libvirt directory found, skipping compilation."
fi

# Adding binaries and libraries to the system paths
if grep --quiet " PATH\=" $HOME/.bashrc; then
    sudo sed -i "s/PATH\=\"/PATH\=\"$(echo $DEST | sed 's/\//\\\//g')\/bin:/" $HOME/.bashrc
else
    echo export PATH="$DEST"/bin:"$PATH" | tee -a $HOME/.bashrc
fi
if grep --quiet LD_LIBRARY_PATH $HOME/.bashrc; then
    sudo sed -i "s/LD\_LIBRARY\_PATH\=\"/LD\_LIBRARY\_PATH\=\"$(echo $DEST | sed 's/\//\\\//g')\/lib:/" $HOME/.bashrc
else
    echo export LD_LIBRARY_PATH="$DEST"/lib:"$LD_LIBRARY_PATH" | tee -a $HOME/.bashrc
fi
source $HOME/.bashrc
