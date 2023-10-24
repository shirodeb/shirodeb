# This file is a configuration file and is not meant to be executed

export PACKAGE="<appid>"
export NAME=""
export VERSION=""
export ARCH=$(utils.misc.get_current_arch)
export URL=""
# autostart,notification,trayicon,clipboard,account,bluetooth,camera,audio_record,installed_apps
export REQUIRED_PERMISSIONS=""

export DESC1=""
export DESC2=""
export DEPENDS="libfuse2"
export PROVIDES=""
export SECTION="misc"
export HOMEPAGE=""
export AUTHOR=""

function test() {
    download
    local downloaded_files="${ret[@]}"
    chmod +x "${downloaded_files[0]}"
    DESKTOPINTEGRATION=1 APPIMAGE_SILENT_INSTALL=1 APPIMAGELAUNCHER_DISABLE=1 "${downloaded_files[0]}" --no-sandbox ||
        DESKTOPINTEGRATION=1 APPIMAGE_SILENT_INSTALL=1 APPIMAGELAUNCHER_DISABLE=1 "${downloaded_files[0]}"

    if zenity --question --no-wrap --text="App ${NAME} OK?"; then
        exit 0 # success
    else
        exit 1 # not success
    fi
}

function build() {
    APPIMAGE_DIR=${SRC_DIR}/${SRC_NAMES[0]}

    # Copy content
    cp -R $APPIMAGE_DIR $APP_DIR/files/

    # Collect .desktop
    utils.desktop.collect "$APPIMAGE_DIR" "-maxdepth 1"
    # Modify .desktop
    local RUN_FILE="/opt/apps/$PACKAGE/files/${SRC_NAMES[0]}/AppRun"
    for desktop_file in $(find $APP_DIR/entries/applications -name "*.desktop"); do
        utils.desktop.edit "Exec" "env DESKTOPINTEGRATION=1 APPIMAGE_SILENT_INSTALL=1 APPIMAGELAUNCHER_DISABLE=1 $RUN_FILE %U" $desktop_file
        utils.desktop.edit "TryExec" "$RUN_FILE" $desktop_file
    done

    # Collect icons
    utils.icon.collect $APPIMAGE_DIR "-maxdepth 1"

    # Fix chrome-sandbox on kernel 4.19
    utils.misc.chrome_sandbox_treat
}
