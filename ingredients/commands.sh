function __ingredients_internal_modify_env() {
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

function __ingredients_internal_clean_up() {
    unset $(declare -x | grep -oP " \K(PREPEND|APPEND|SET|DEFAULT)_ENV__[^=]*" | xargs)
}

# Checkout used component
function what_is_used() {
    # TODO
    # This is used for generate runtime bundle from ingredients and packing
    return 0
}

# Add ingredients
function add() {
    local ingredient_name="$1"
    local type="${2:-devel}"
    local ingredient_root="$INGREDIENTS_DIR/$ingredient_name"
    if [[ ! -d "$ingredient_root" ]]; then
        log.error "$ingredient_name is not an ingredient"
        return -1
    fi
    local ingredient_root="$(readlink -f "$ingredient_root")"
    local ingredient_content_root="$ingredient_root"
    if [[ -f "$ingredient_root/base.sh" ]]; then
        source "$ingredient_root/base.sh"
        ingredient_content_root="${INGREDIENT_ROOT:-$ingredient_content_root}"

        local dname="INGREDIENT_DEPENDS_${type^^}"
        eval depends="(\"\${$dname[@]}\")"

        if [[ ! -z "${depends[@]}" ]]; then
            for d in "${depends[@]}"; do
                if $(LANG=C apt list -qq "$d" 2>/dev/null | grep -q "\[installed\]"); then
                    log.debug "$type depend \`$d\` is installed."
                else
                    log.debug "installing $type depend \`$d\`..."
                    # TODO: figuring out a way not use sudo
                    sudo apt install -y "$d"
                    log.debug "$type depend \`$d\` is installed."
                fi
            done
        fi
    fi

    if [[ -f "$ingredient_root/${type}.sh" ]]; then
        log.info "preparing ${type} environment for $ingredient_name"
        __ingredients_internal_clean_up
        source "$ingredient_root/${type}.sh"

        local la=$(declare -x | grep -oP " \K(PREPEND|APPEND)_ENV__[^=]*")
        local sa=$(declare -x | grep -oP " \K(SET|DEFAULT)_ENV__[^=]*")

        for l in ${la[@]}; do
            local type="$(tr "[A-Z]" "[a-z]" <<<${l%%_*})"
            local name="${l/${type^^}_ENV__/}"
            eval a="(\"\${$l[@]}\")"
            local sep=${a[0]}

            for value in "${a[@]:1}"; do
                local value=${value/\%ROOT\%/${ingredient_content_root}}
                __ingredients_internal_modify_env "$type" "$name" "$value" "$sep"
            done
        done

        for s in ${sa[@]}; do
            local type="$(tr "[A-Z]" "[a-z]" <<<${s%%_*})"
            local name="${s/${type^^}_ENV__/}"
            local value=${!s}
            local value=${value/\%ROOT\%/${ingredient_content_root}}
            if [[ $type == "set" ]]; then
                eval "export ${name}=\"$value\""
                log.debug "set" \`"$name"\` to \'$value\'
            elif [[ $type == "default" && -z "${!name}" ]]; then
                eval "export ${name}=\"$value\""
                log.debug "set" \`"$name"\` to \'$value\'
            fi
        done

        __ingredients_internal_clean_up
    else
        log.error "${type} environment for $ingredient_name is not existed."
        exit -1
    fi

    log.info "$ingredient_name is added to the pot!"
}

# List all ingredients
function list() {
    /bin/ls -1 "$INGREDIENTS_DIR"
}

# Enter build environment
function enter() {
    export PS1="\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\\n(env)$ "
    export -f add list
    export -f $(declare -F | grep -oP "log.*" | xargs)
    export -f $(declare -F | grep -oP "__ingredients.*" | xargs)
    /bin/bash --noprofile --norc
}

if [[ -z "$INGREDIENTS_DIR" ]]; then
    log.error "No INGREDIENTS_DIR set."
    return -1
fi

"$@"
