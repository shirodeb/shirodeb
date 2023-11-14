#!env bash

# This file provides functions for internal use only in shirodeb
# build.sh should never reference these functions

# ===== Download source =====

function __internal.download_snap_to() {
    local url="$1"
    local to_dir="$(dirname $2)"
    local filename="$(basename $2)"

    local download_command=$(
        curl --retry 5 $download_url |
            grep 'code id="snap-install"' |
            sed "s#^.*<code id.*\?>\(.*\)</code>.*\$#\1#g" | sed "s/sudo.*install\s//"
    )
    pushd $to_dir
    local fn=$(echo $download_command | xargs snap download | tee /dev/stderr | grep -oP "install \K(.*)")
    mv $fn $filename
    rm -rf $(echo $fn | sed "s/\.snap$/.assert/")
    popd
    return 0
}

function __internal.download.curl() {
    local url="$1"
    local to="$2"
    if ! curl --retry 5 -Lo "$to" "$url"; then
        return -1
    fi
    return 0
}

function __internal.download.aria2() {
    local url="$1"
    local to="$2"
    if ! aria2c -c -x 16 -s 16 -d "$(dirname "$to")" "$url" -o "$(basename "$to")" --summary-interval=1; then
        return -1
    fi
    return 0
}

# Required global variable:
# - DOWNLOAD_DIR: Target download dir
# Optional global variable:
# - LOCAL_DOWNLOAD_DIR: Local cache of downloading files
function __internal.download() {
    local LOCAL_DD=${LOCAL_DOWNLOAD_DIR:-${DOWNLOAD_DIR}}
    local download_result=()
    local url=""

    if [[ -z "$@" ]]; then
        ret="${download_result[@]}"
        return 0
    fi

    for url in "$@"; do
        local download_to
        local download_url="$url"
        local download_filename

        if [[ "$url" =~ "::" ]]; then
            # Url is provided with preferred filename
            download_filename=$(awk -F '::' '{print $1}' <<<$url)
            download_url=$(awk -F '::' '{print $2}' <<<$url)
        else
            download_filename=$(basename $url)
        fi
        download_to=${DOWNLOAD_DIR}/${download_filename}

        if [[ -f "$download_to" ]]; then
            log.info "$download_filename is existed. Skip downloading..."
            download_result[${#download_result[@]}]=$download_to
            continue
        fi
        if [[ -f "$LOCAL_DD/$download_filename" ]]; then
            log.info "$download_filename is cached. Skip downloading..."
            ln -s "$LOCAL_DD/$download_filename" "$download_to"
            download_result[${#download_result[@]}]=$download_to
            continue
        fi
        log.info "Downloading $download_filename"

        if [[ $download_url =~ https://snapcraft.io/* ]]; then
            __internal.download_snap_to "$download_url" "$LOCAL_DD/$download_filename"
        else
            if [[ -z $PREFERRED_DOWNLOADER ]]; then
                local PREFERRED_DOWNLOADER="aria2"
            fi
            download_url=${download_url// /%20}
            case $PREFERRED_DOWNLOADER in
            aria2) __internal.download.aria2 "$download_url" "$LOCAL_DD/$download_filename" ;;
            curl) __internal.download.curl "$download_url" "$LOCAL_DD/$download_filename" ;;
            esac
            if [[ $? != 0 ]]; then
                log.error "Downloading $download_filename from $download_url Failed"
                rm -f "$LOCAL_DD/$download_filename"
                exit -1
            fi
        fi
        ln -s "$LOCAL_DD/$download_filename" "$download_to"
        download_result[${#download_result[@]}]=$download_to
    done
    ret="${download_result[@]}"
    return 0
}

# ===== Unarchive source =====

function __internal.unar.deb() {
    local fields=$(LC_ALL=C dpkg -f "$1" 2>&1)

    if [[ "$(echo "$fields" | wc -l)" == 1 ]] && [[ "$fields" =~ "tar.zst" ]]; then
        # New style zstd deb package
        log.info "Deb is packed by new style zstd format. Using unzstd to unarchive"

        local tempd=$(mktemp -d)
        if [[ ! -d "$tempd" ]]; then
            log.error 'Temp directory not make'
            exit -1
        fi
        pushd "$tempd"
        ar x "$1" control.tar.zst
        ar x "$1" data.tar.zst
        mkdir DEBIAN
        [ -f control.tar.zst ] && tar --use-compress-program=unzstd -xvf control.tar.zst -C DEBIAN
        local package_name="$(grep Package DEBIAN/control | sed 's/^Package: //g')"
        ret=$package_name
        local base_dir="$2/$package_name"
        if [[ -f ${base_dir}/DEBIAN/control ]]; then
            log.info "$(basename $1) is already unarchived"
            return 0
        fi
        mkdir -p "${base_dir}/"
        mv DEBIAN "$base_dir"
        mv data.tar.zst "$base_dir"
        popd
        rm -rf "$tempd"

        pushd "$base_dir"
        [[ -f data.tar.zst ]] && tar --use-compress-program=unzstd -xvf data.tar.zst
        rm -f data.tar.zst
        popd
    else
        # Regular old fashion deb package
        local folder_name=$(dpkg -f $1 Package)
        ret=$folder_name
        local base_dir="$2/$folder_name"
        if [[ -f ${base_dir}/DEBIAN/control ]]; then
            log.info "$(basename $1) is already unarchived"
            return 0
        fi
        mkdir -p "${base_dir}/DEBIAN"
        dpkg -e "$1" "${base_dir}/DEBIAN"
        dpkg -x "$1" "${base_dir}/"
    fi
    return 0
}

function __internal.unar.app-image() {
    local bname=$(basename "$1")
    local name="${bname/.AppImage/}"
    local base_dir="$2/$name"
    ret=$name
    if [[ -d "$base_dir" ]]; then
        log.info "$(basename $1) is already unarchived"
        return 0
    fi
    chmod +x "$1"
    env DESKTOPINTEGRATION=1 APPIMAGE_SILENT_INSTALL=1 APPIMAGELAUNCHER_DISABLE=1 "$1" --appimage-extract
    mv ./squashfs-root $base_dir
    return 0
}

function __internal.unar.snap() {
    if ! where unsquashfs >/dev/null; then
        log.error "unsquashfs is not found. Unable to archive."
        exit -1
    fi
    local bname=$(basename "$1")
    local name="${bname/.snap/}"
    local base_dir="$2/$name"
    ret=$name
    if [[ $(/usr/bin/ls -Aq "$base_dir") != "" ]]; then
        log.info "$(basename $1) is already unarchived"
        return 0
    fi
    unsquashfs -f -d "$base_dir" "$1"
    return 0
}

function __internal.unar.with-unar() {
    # TODO: guess whether tarballs is nested with a folder or something else and point it out
    ret=""
    unar -s -o "$2" "$1"
    if [ $? != 0 ]; then
        case "$1" in
        # TODO: fallback more when needed
        *.zip) unzip -o -d "$2" "$1" ;;
        *) log.error "Unable to unar $1 and we have no fallback for this file extension." && exit -1 ;;
        esac
    fi
    if [ $? != 0 ]; then
        log.error 'Unarchive failed'
        exit -1
    fi
    return 0
}

function __internal.unar() {
    local downloaded_file="$1"
    local unar_to_dir="$2"

    log.info "Unarchiving $(basename $downloaded_file)"
    case "$downloaded_file" in
    *.deb) __internal.unar.deb "$downloaded_file" "$unar_to_dir" ;;
    *.AppImage) __internal.unar.app-image "$downloaded_file" "$unar_to_dir" ;;
    *.snap) __internal.unar.snap "$downloaded_file" "$unar_to_dir" ;;
    *.tar.*) __internal.unar.with-unar "$downloaded_file" "$unar_to_dir" ;;
    *.txz) __internal.unar.with-unar "$downloaded_file" "$unar_to_dir" ;;
    *.tbz) __internal.unar.with-unar "$downloaded_file" "$unar_to_dir" ;;
    *.tgz) __internal.unar.with-unar "$downloaded_file" "$unar_to_dir" ;;
    *.zip) __internal.unar.with-unar "$downloaded_file" "$unar_to_dir" ;;
    *.7z) __internal.unar.with-unar "$downloaded_file" "$unar_to_dir" ;;
    *)
        log.warn "Extension for $(basename $downloaded_file) is unrecognized. Using \`file\` to determinate"
        local file_type="$(file -b $(readlink -f $downloaded_file))"
        case $file_type in
        *Debian*) __internal.unar.deb "$downloaded_file" "$unar_to_dir" ;;
        *)
            log.info "$file_type is unrecognized. Link file to \$SRC_DIR"
            ret="$(basename "$downloaded_file")"
            ln -s "$downloaded_file" "$unar_to_dir/$ret"
            ;;
        esac
        ;;
    esac
    return 0
}

# ===== Override built-in functions =====
function pushd() {
    builtin pushd "$@" >/dev/null
}

function popd() {
    builtin popd "$@" >/dev/null
}
