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
export DEPENDS=""
export SECTION="misc"
export PROVIDE=""
export HOMEPAGE=""
export AUTHOR=""

function build() {
    return 0
}
