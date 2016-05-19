#!/bin/bash

openrpt_menu() {
    log "Opened openrpt menu"

    while true; do

        CC=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title OpenRPT\ Menu )" 0 0 1 --cancel-button "Cancel" --ok-button "Select" \
            "1" "Install Package" \
            "2" "Build from source" \
            "3" "Install xvfb" \
            "4" "Remove xvfb" \
            "5" "Return to main menu" \
            3>&1 1>&2 2>&3)
        
        RET=$?
        
        if [ $RET -ne 0 ]; then
            break
        else
            case "$CC" in
            "1") log_choice install_openrpt ;;
            "2") log_choice build_openrpt ;;
            "3") log_choice install_xvfb ;;
            "4") log_choice remove_xvfb ;;
            "5") break ;;
            *) msgbox "Don't know how you got here! Please report on GitHub >> openrpt_menu $CC" && break ;;
            esac
        fi
    done
}

install_openrpt() {

    log_arg
    log "Installing OpenRPT from apt..."
    log_exec sudo apt-get -y -qq install openrpt
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "There was an error installing OpenRPT. Check the log and correct any issues before trying again"
    fi
    return $RET

}

build_openrpt() {

    cd $WORKDIR || die "Couldn't cd $WORKDIR"

    log "preparing to build OpenRPT from source"
    rm -rf openrpt
    log_exec git clone -q https://github.com/xtuple/openrpt.git || die "Can't clone openrpt"
    log_exec runasroot apt-get install -qq --force-yes qt4-qmake libqt4-dev libqt4-sql-psql || die "Can't install Qt"
    cd openrpt || die "Can't cd openrpt"
    OPENRPT_VER=master #TODO: OPENRPT_VER=`latest stable release`
    log_exec git checkout -q $OPENRPT_VER || die "Can't checkout openrpt"
    log "Starting OpenRPT build (this will take a few minutes)..."
    qmake || die "Can't qmake openrpt"
    make > /dev/null || die "Can't make openrpt"
    log_exec runasroot mkdir -p /usr/local/bin || die "Can't make /usr/local/bin"
    log_exec runasroot mkdir -p /usr/local/lib || die "Can't make /usr/local/lib"
    log_exec runasroot tar cf - bin lib | runasroot tar xf - -C /usr/local || die "Can't install OpenRPT"
    log_exec runasroot ldconfig || die "ldconfig failed"

}

install_xvfb() {

    log "Installing xvfb..."
    log_exec sudo apt-get -y install xvfb
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "There was an error installing xvfb. Check the log and correct any issues before trying again"
    fi
    return $RET

}

remove_xvfb() {

    if (whiptail --title "Are you sure?" --yesno "Uninstall xvfb?" --yes-button "Yes" --no-button "No" 10 60) then
        log "Uninstalling xvfb..."
        log_exec sudo apt-get -y remove xvfb
        RET=$?
        return $RET
    else
        return 0
    fi

}

install_xtuple_xvfb() {
    log "Installing xtuple-Xvfb to /etc/init.d..."
    log_exec sudo cp $WORKDIR/templates/xtuple-Xvfb /etc/init.d 
    log_exec sudo chmod 755 /etc/init.d/xtuple-Xvfb 
    log_exec sudo update-rc.d xtuple-Xvfb defaults
    log_exec sudo service xtuple-Xvfb start
}

setup_webprint() {
    install_openrpt
    install_xvfb
    install_xtuple_xvfb
}
