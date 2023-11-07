#!env bash

# This file provides functions for internal use only in ingredients

function ingredients.internal.modify_env() {
    local type="$1"
    local var_name="$2"
    local var_value="$3"
    local var_sep="${4:-:}"
    log.debug "$type" \""$var_value"\" to \`$var_name\` by \'$var_sep\'
    if [[ $type == "prepend" ]]; then
        eval "export ${var_name}=\"\${var_value}\${$var_name:+$var_sep\$$var_name}\""
    elif [[ $type == "append" ]]; then
        eval "export ${var_name}=\"\${$var_name:+\$$var_name$var_sep}\${var_value}\""
    fi
}

function ingredients.internal.modify_env_fake() {
    local type="$1"
    local var_name="$2"
    local var_value="$3"
    local var_sep="${4:-:}"
    if [[ $type == "prepend" ]]; then
        echo "export ${var_name}=\"${var_value}$var_sep\$$var_name\""
    elif [[ $type == "append" ]]; then
        echo "export ${var_name}=\"\$$var_name$var_sep${var_value}\""
    fi
}

function ingredients.internal.clean_up() {
    unset $(declare -x | grep -oP " \K(PREPEND|APPEND|SET|DEFAULT)_ENV__[^=]*" | xargs)
    unset $(declare -- | grep -oP "^INGREDIENT_[^=]*" | xargs)
}

function ingredients.internal.copy_content() {
    # Bundle into package
    local v=${1%*/}
    local bundle_root="/opt/apps/$PACKAGE/files/shirodeb-ingredients/$ingredient_name"
    local r_value=${v/\%ROOT\%/${bundle_root}}

    local local_content=${v/\%ROOT\%/${ingredient_content_root}}
    local parent_root="$(dirname $(readlink -fm $r_value))"
    mkdir -p "$PKG_DIR/$parent_root"
    rsync -ap $local_content/ $PKG_DIR/$r_value
    ret="$r_value"
}
