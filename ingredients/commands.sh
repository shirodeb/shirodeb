# Checkout used component
function ingredients.what_is_used() {
    # TODO
    # This is used for generate runtime bundle from ingredients and packing
    return 0
}

# Add ingredients
function ingredients.add() {
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
        ingredients.internal.clean_up
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

        ingredients.internal.clean_up
    fi

    if [[ -f "$ingredient_root/${type}.sh" ]]; then
        log.info "preparing ${type} environment for $ingredient_name"
        ingredients.internal.clean_up
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
                ingredients.internal.modify_env "$type" "$name" "$value" "$sep"
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

        ingredients.internal.clean_up
    else
        log.error "${type} environment for $ingredient_name is not existed."
        return -1
    fi

    log.info "$ingredient_name is added to the pot!"
}

# List all ingredients
function ingredients.list() {
    /bin/ls -1 "$INGREDIENTS_DIR"
}

# Enter build environment
function ingredients.enter() {
    export PS1="\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\\n(env)$ "
    export -f ingredients.add ingredients.list
    export -f $(declare -F | grep -oP "log.*" | xargs)
    export -f $(declare -F | grep -oP "ingredients.*" | xargs)
    set -a
    function list() { ingredients.list "$@"; }
    function add() { ingredients.add "$@"; }
    set +a
    /bin/bash --noprofile --norc
}

# Append runtime deps to DEPENDS
function ingredients.add_runtime_depends() {
    local ingredient_name="$1"
    local ingredient_root="$INGREDIENTS_DIR/$ingredient_name"
    local ingredient_root="$(readlink -f "$ingredient_root")"

    if [[ -f "$ingredient_root/base.sh" ]]; then
        source "$ingredient_root/base.sh"
        ingredient_content_root="${INGREDIENT_ROOT:-$ingredient_content_root}"

        local depends="${INGREDIENT_DEPENDS_RUNTIME[@]}"

        if [[ ! -z "${depends[@]}" ]]; then
            for d in "${depends[@]}"; do
                ingredients.internal.modify_env "prepend" "DEPENDS" "$d" ", "
            done
        fi
    fi
}

# Generate export statement for runtime
function ingredients.make_runtime_export() {
    local ingredient_name="$1"
    local ingredient_root="$INGREDIENTS_DIR/$ingredient_name"
    local ingredient_root="$(readlink -f "$ingredient_root")"
    local ingredient_content_root="$ingredient_root"
    if [[ -f "$ingredient_root/base.sh" ]]; then
        ingredients.internal.clean_up
        source "$ingredient_root/base.sh"
        ingredient_content_root="${INGREDIENT_ROOT:-$ingredient_content_root}"
        ingredients.internal.clean_up
    fi

    if [[ -f "$ingredient_root/runtime.sh" ]]; then
        ingredients.internal.clean_up
        source "$ingredient_root/runtime.sh"

        local la=$(declare -x | grep -oP " \K(PREPEND|APPEND)_ENV__[^=]*")
        local sa=$(declare -x | grep -oP " \K(SET|DEFAULT)_ENV__[^=]*")

        for l in ${la[@]}; do
            local type="$(tr "[A-Z]" "[a-z]" <<<${l%%_*})"
            local name="${l/${type^^}_ENV__/}"
            eval a="(\"\${$l[@]}\")"
            local sep=${a[0]}

            for value in "${a[@]:1}"; do
                local value=${value/\%ROOT\%/${ingredient_content_root}}
                ingredients.internal.modify_env_fake "$type" "$name" "$value" "$sep"
            done
        done

        for s in ${sa[@]}; do
            local type="$(tr "[A-Z]" "[a-z]" <<<${s%%_*})"
            local name="${s/${type^^}_ENV__/}"
            local value=${!s}
            local value=${value/\%ROOT\%/${ingredient_content_root}}
            if [[ $type == "set" ]]; then
                echo "export ${name}=\"$value\""
            elif [[ $type == "default" ]]; then
                cat <<EOF
if [[ -z "\$${name}" ]]; then
    # Not use default substitution here 
    export ${name}="$value"
fi
EOF
            fi
        done
        ingredients.internal.clean_up
    fi
}
