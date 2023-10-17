#!/bin/env bash

SCRIPT_ROOT=$(dirname $(readlink -f $0))

source $SCRIPT_ROOT/internal.sh
source $SCRIPT_ROOT/utils.sh
source $SCRIPT_ROOT/commands.sh

log.info "ShiroDEB 1.0 ($SCRIPT_ROOT)"

if [[ -f $SCRIPT_ROOT/profile ]]; then source $SCRIPT_ROOT/profile; fi

if [[ -z $TEMPLATES_ROOT ]]; then
    export TEMPLATES_ROOT=${SCRIPT_ROOT}/templates
fi

if [[ "$1" == "start" ]]; then
    # Special treat for start command.
    "$@"
    exit 0
fi

BUILD_SH=$(utils.misc.find_up "build.sh")

if [[ ! -f "$BUILD_SH" ]]; then
    log.error build.sh is not found
    exit -1
fi

source "$BUILD_SH"

# Check necessary variables
if [[ -z $PACKAGE || -z $VERSION || -z $ARCH ]]; then
    log.error "Some key variable is not present or empty in build.sh"
    exit -1
fi

# Global variables from build.sh
ROOT_DIR="${BUILD_SH%/*}"
PKGVER_NAME="${PACKAGE}-${VERSION}"
SRC_DIR="$ROOT_DIR/src/$PKGVER_NAME"
PKG_DIR="$ROOT_DIR/pkg/$PKGVER_NAME"
DOWNLOAD_DIR="$ROOT_DIR/downloads"
OUTPUT_DIR="$ROOT_DIR/output"
APP_DIR="$PKG_DIR/opt/apps/$PACKAGE"

mkdir -p $SRC_DIR $PKG_DIR $APP_DIR $DOWNLOAD_DIR $OUTPUT_DIR

log.info "ShiroDEB for $PACKAGE"

if ! LC_ALL=C type build | grep -q function; then
    log.error "You must specify build function inside build.sh"
    exit -1
fi

"$@"
