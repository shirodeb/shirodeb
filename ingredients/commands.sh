# Checkout used component
function ingredients.what_is_used() {
    # TODO
    # This is used for generate runtime bundle from ingredients and packing
    return 0
}

# Add ingredients
function ingredients.get_ingredient_full_name() {
    if [[ -z "$ingredients_db" ]]; then
        ingredients.refresh_index
    fi

    local triple=""
    IFS='-' triple=($(echo "$@"))
    local i_name="${triple[0]}"
    local i_ver="${triple[1]}"
    local i_arch="$(utils.misc.get_current_arch)"

    if [[ $(jq -r ".\"$i_name\"" <<<"$ingredients_db") == "null" ]]; then
        log.error "Ingredients $i_name does not exist"
        return -1
    fi

    if [[ -z "$i_ver" ]]; then
        i_ver=$(jq -r ".\"$i_name\".\"$i_arch\"[]" <<<"$ingredients_db" 2>/dev/null | sort --version-sort -r | head -1)
        if [[ -z "$i_ver" ]]; then
            log.error "Ingredients $i_name does not exist on $i_arch"
            return -1
        fi
        log.info "Chose $i_ver for $i_name"
    fi

    if [[ $(jq -r ".\"$i_name\".\"$i_arch\" | index(\"$i_ver\")" <<<"$ingredients_db") == "null" ]]; then
        if [[ $(jq -r ".\"$i_name\".\"$i_arch\"" <<<"$ingredients_db") == "null" ]]; then
            log.error "Ingredients $i_name does not exist on $i_arch"
            return -1
        else
            log.error "Ingredients $i_name has no version $i_ver on $i_arch"
            return -1
        fi
    else
        echo "$i_name-$i_ver-$i_arch"
        return 0
    fi
}

function ingredients.add() {
    local ingredient_name="$(ingredients.get_ingredient_full_name $1)"
    if [[ $? != 0 ]]; then
        return -1
    fi
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
    # /bin/ls -1 "$INGREDIENTS_DIR"
    if [[ -z "$ingredients_db" ]]; then
        ingredients.refresh_index
    fi
    local table="\033[1;00m\033[0m"
    local arches="$(jq -r '[keys[] as $k | .[$k] | keys[]] | unique[]' <<<"$ingredients_db")"
    for arch in $arches; do
        table="$table\t|\t\033[1;37m$arch\033[0m"
    done
    table="$table\n"
    for i_name in $(jq -r 'keys | sort[]' <<<"$ingredients_db"); do
        table="$table\033[1;33m$i_name\033[0m"
        for arch in $arches; do
            table="$table\t|\t"
            for i_ver in $(jq -r ".\"$i_name\".\"$arch\"[]" <<<"$ingredients_db" 2>/dev/null); do
                table="$table\033[1;36m$i_ver\033[0m, "
            done
            table=${table%*, }
        done
        table="$table\n"
    done
    table=${table%*\\n}
    echo -e $table | column -s$'\t' -t
}

# Enter build environment
function ingredients.enter() {
    export PS1="\[\e]0;\u@\h: \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\\n(env)$ "
    export -f ingredients.add ingredients.list
    export -f $(declare -F | grep -oP "log.*" | xargs)
    export -f $(declare -F | grep -oP "utils.*" | xargs)
    export -f $(declare -F | grep -oP "ingredients.*" | xargs)
    set -a
    function list() { ingredients.list "$@"; }
    function add() { ingredients.add "$@"; }
    set +a
    /bin/bash --noprofile --norc
}

# Append runtime deps to DEPENDS
function ingredients.add_runtime_depends() {
    local ingredient_name="$(ingredients.get_ingredient_full_name $1)"
    if [[ $? != 0 ]]; then
        return -1
    fi
    local ingredient_root="$INGREDIENTS_DIR/$ingredient_name"
    local ingredient_root="$(readlink -f "$ingredient_root")"

    if [[ -f "$ingredient_root/base.sh" ]]; then
        source "$ingredient_root/base.sh"
    fi
    ingredient_content_root="${INGREDIENT_ROOT:-$ingredient_root}"
    local depends="${INGREDIENT_DEPENDS_RUNTIME[@]}"

    if [[ ! -z "${depends[@]}" ]]; then
        for d in "${depends[@]}"; do
            log.info "Add runtime-depends $d"
            ingredients.internal.modify_env "prepend" "DEPENDS" "$d" ", "
        done
    fi
}

# Generate export statement for runtime
function ingredients.make_runtime_export() {
    local ingredient_name="$(ingredients.get_ingredient_full_name $1)"
    if [[ $? != 0 ]]; then
        return -1
    fi
    local ingredient_root="$INGREDIENTS_DIR/$ingredient_name"
    local ingredient_root="$(readlink -f "$ingredient_root")"
    local ingredient_content_root="$ingredient_root"
    local has_root=0
    if [[ -f "$ingredient_root/base.sh" ]]; then
        ingredients.internal.clean_up
        source "$ingredient_root/base.sh"
        if [ ! -z "$INGREDIENT_ROOT" ]; then
            # IMPORTANT NOTE: If INGREDIENT_ROOT is specified in base.sh
            # Then there would be no bundle
            has_root=1
        fi
        ingredient_content_root="${INGREDIENT_ROOT:-$ingredient_content_root}"
        ingredients.internal.clean_up
    fi

    if [[ -f "$ingredient_root/runtime.sh" ]]; then
        ingredients.internal.clean_up
        source "$ingredient_root/runtime.sh"

        local la=$(declare -x | grep -oP " \K(PREPEND|APPEND)_ENV__[^=]*")
        local sa=$(declare -x | grep -oP " \K(SET|DEFAULT)_ENV__[^=]*")

        if [ $has_root = 0 ]; then
            if [ ! -z "$la" -o ! -z "$sa" ]; then
                log.info "Bundling $ingredient_name"
            fi
        fi

        for l in ${la[@]}; do
            local type="$(tr "[A-Z]" "[a-z]" <<<${l%%_*})"
            local name="${l/${type^^}_ENV__/}"
            eval a="(\"\${$l[@]}\")"
            local sep=${a[0]}

            local value=""
            for value in "${a[@]:1}"; do
                if [[ "$value" =~ "%ROOT%" ]]; then
                    if [ $has_root = 1 ]; then
                        value=${value/\%ROOT\%/${ingredient_content_root}}
                    else
                        ingredients.internal.copy_content "$value"
                        value="$ret"
                        unset ret
                    fi
                fi
                ingredients.internal.modify_env_fake "$type" "$name" "$value" "$sep"
            done
        done

        for s in ${sa[@]}; do
            local type="$(tr "[A-Z]" "[a-z]" <<<${s%%_*})"
            local name="${s/${type^^}_ENV__/}"
            local value=${!s}

            # TODO: Reuse this codes
            if [[ "$value" =~ "%ROOT%" ]]; then
                if [ $has_root = 1 ]; then
                    value=${value/\%ROOT\%/${ingredient_content_root}}
                else
                    ingredients.internal.copy_content "$value"
                    value="$ret"
                    unset ret
                fi
            fi

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

function ingredients.refresh_index() {
    declare -g ingredients_db="{}"
    local ig
    for i in $(/bin/ls -1 "$INGREDIENTS_DIR"); do
        if [ ! -d "$INGREDIENTS_DIR/$i" ]; then continue; fi
        IFS='-' read -ra ig <<<"$i"
        local i_name="${ig[0]}"
        local i_ver="${ig[1]}"
        local i_arch="${ig[2]}"
        ingredients_db=$(jq -c ".\"$i_name\".\"$i_arch\"+=[\"$i_ver\"]" <<<"$ingredients_db")
    done
}
