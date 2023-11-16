#!/usr/bin/env bash

SCRIPT_ROOT=$(dirname $(readlink -f $0))

source $SCRIPT_ROOT/internal.sh
source $SCRIPT_ROOT/utils.sh
source $SCRIPT_ROOT/commands.sh
source $SCRIPT_ROOT/ingredients/internal.sh
source $SCRIPT_ROOT/ingredients/commands.sh

log.info "ShiroDEB 1.0 ($SCRIPT_ROOT)"

if [[ -f $SCRIPT_ROOT/profile ]]; then source $SCRIPT_ROOT/profile; fi

if [[ -z $TEMPLATES_ROOT ]]; then
    export TEMPLATES_ROOT=${SCRIPT_ROOT}/templates
fi

__NO_NEED_BUILD_SH=("start" "ingred" "ingredient")
if [[ $(echo ${__NO_NEED_BUILD_SH[@]} | fgrep -w $1) ]]; then
    # Special treat for start command.
    "$@"
    exit $?
fi

BUILD_SH=$(utils.misc.find_up "build.sh")

if [[ ! -f "$BUILD_SH" ]]; then
    log.error build.sh is not found
    exit -1
fi

source "$BUILD_SH"

if [[ ! -z "$INGREDIENTS[@]" ]]; then
    log.info "Setup ingredients..."
    for ing in "${INGREDIENTS[@]}"; do
        ingredients.add "$ing"
        if [ $? = 0 ]; then
            log.info "Ingredient $ing setup complete."
        elif [ $? = 1 ]; then
            log.info "Ingredient $ing has no devel environment."
        else
            log.error "Ingredient $ing setup failed..."
            exit -1
        fi
    done
fi

# Global variables from build.sh
ROOT_DIR="${BUILD_SH%/*}"
DOWNLOAD_DIR="$ROOT_DIR/downloads"
OUTPUT_DIR="$ROOT_DIR/output"

# Check if `function prepare` is available
# `function prepare` is used for prepare meta info for build.sh
if LC_ALL=C type prepare 2>&1 | grep -q function; then
    log.info "Preparing meta info for build..."
    prepare "$@"
fi

# Check necessary variables
if [[ -z $PACKAGE || -z $VERSION || -z $ARCH ]]; then
    log.error "Some key variable is not present or empty in build.sh"
    exit -1
fi

PKGVER_NAME="${PACKAGE}-${VERSION}"
SRC_DIR="$ROOT_DIR/src/$PKGVER_NAME"
PKG_DIR="$ROOT_DIR/pkg/$PKGVER_NAME"
APP_DIR="$PKG_DIR/opt/apps/$PACKAGE"

mkdir -p $SRC_DIR $PKG_DIR $APP_DIR $DOWNLOAD_DIR $OUTPUT_DIR

log.info "ShiroDEB for $PACKAGE"

if ! LC_ALL=C type build | grep -q function; then
    log.error "You must specify build function inside build.sh"
    exit -1
fi

"$@"
