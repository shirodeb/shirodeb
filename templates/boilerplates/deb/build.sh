# This file is a configuration file and is not meant to be executed

export PACKAGE="<appid>"
export NAME=""
export VERSION=""
export ARCH=$(utils.misc.get_current_arch)
export URL=""
# autostart,notification,trayicon,clipboard,account,bluetooth,camera,audio_record,installed_apps
export REQUIRED_PERMISSIONS=""

function build() {
    local DEB_SRC_DIR="$SRC_DIR/${SRC_NAMES[0]}"
    if [[ $1 == "check" ]]; then
        whereis exa >/dev/null && exa --tree $DEB_SRC_DIR && exit 0
        whereis tree >/dev/null && tree $DEB_SRC_DIR && exit 0
        find $DEB_SRC_DIR
        exit 0
    fi

    # Copy content (*manually specify*)
    log.debug "Copy content..."
    cp -R $DEB_SRC_DIR/* $APP_DIR/files/
    local EXEC_PATH=""

    # Collect .desktop
    log.debug "Collect .desktop files..."
    utils.desktop.collect "$DEB_SRC_DIR/usr/share/applications"
    # Modify .desktop
    for desktop_file in $(find $APP_DIR/entries/applications -name "*.desktop"); do
        utils.desktop.edit "Exec" "/opt/apps/$PACKAGE/files/${EXEC_PATH} %U" $desktop_file
        utils.desktop.edit "TryExec" "/opt/apps/$PACKAGE/files/${EXEC_PATH}" $desktop_file
    done

    # Collect icons
    log.debug "Collect icons..."
    utils.icon.collect $DEB_SRC_DIR/usr/share/icons

    # Fix chrome-sandbox on kernel 4.19
    utils.misc.chrome_sandbox_treat

    # Get details from original debian/control
    log.debug "Reading existing control file..."
    utils.misc.read_control_from "$DEB_SRC_DIR/DEBIAN/control"
}
