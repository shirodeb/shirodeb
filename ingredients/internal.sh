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
