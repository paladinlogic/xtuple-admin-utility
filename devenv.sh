#!/bin/bash

dev_menu() {
    log "Opened development menu"

    while true; do

        CC=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title Development\ Menu )" 0 0 1 --cancel-button "Cancel" --ok-button "Select" \
            "1" "Install Development Pre-reqs" \
            "2" "Build & Install Qt 5.5.1" \
            "3" "Build xTuple" \
            3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -ne 0 ]; then
            break
        else
            case "$CC" in
            "1") install_dev_prereqs ;;
            "2") build_qt5 ;;
            "3") build_xtuple ;;
            *) msgbox "Don't know how you got here! Please report on GitHub >> dev_menu $CC" && break ;;
            esac
        fi
    done
}

install_dev_prereqs() {

    log "Installing Development Environment pre-requisites..."
    log_exec sudo apt-get update
    log_exec sudo apt-get -y -qq install libpq-dev \
                                         libkrb5-dev \
                                         libmysqlclient-dev \
                                         libpam0g-dev \
                                         libperl-dev \
                                         readline-common \
                                         libreadline6-dev \
                                         libsqlite0-dev \
                                         libssl-dev \
                                         libldap2-dev \
                                         libxml2-dev \
                                         libxslt1-dev \
                                         zlib1g-dev \
                                         unixodbc-dev \
                                         build-essential \
                                         xorg \
                                         git \
                                         perl \
                                         python \
                                         "^libxcb.*" \
                                         libx11-xcb-dev \
                                         libglu1-mesa-dev \
                                         libxrender-dev \
                                         libxi-dev \
                                         flex \
                                         bison \
                                         gperf \
                                         libicu-dev \
                                         ruby \
                                         libssl-dev \
                                         libxcursor-dev \
                                         libxcomposite-dev \
                                         libxdamage-dev \
                                         libxrandr-dev \
                                         libfontconfig1-dev \
                                         libcap-dev \
                                         libbz2-dev \
                                         libgcrypt11-dev \
                                         libpci-dev \
                                         libnss3-dev \
                                         build-essential \
                                         libxcursor-dev \
                                         libxcomposite-dev \
                                         libxdamage-dev \
                                         libxrandr-dev \
                                         libdrm-dev  \
                                         libasound2-dev \
                                         gperf \
                                         libcups2-dev \
                                         libpulse-dev \
                                         libudev-dev \
                                         libgstreamer0.10-dev \
                                         libgstreamer-plugins-base0.10-dev \
                                         libxtst-dev
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "There was an error installing pre-requisites. Check the log and correct any issues before trying again."
    fi
    return $RET

}

build_qt5() {

    log "Building Qt5 from source"

    cd $WORKDIR
    wget http://download.qt.io/official_releases/qt/5.5/5.5.1/single/qt-everywhere-opensource-src-5.5.1.tar.gz
    tar zxvf qt-everywhere-opensource-src-5.5.1.tar.gz
    cd qt-everywhere-opensource-src-5.5.1
    # we will likely want to embrace qtwebengine but for now it doubles the build time...
    log_exec ./configure -qt-sql-psql -qt-sql-sqlite -qt-zlib -qt-libpng -qt-libjpeg -nomake examples -skip qtwebengine -opensource -confirm-license
    RET=$?
    if [ $RET -ne 0 ]; then
        log "There was an error running configure. Check the log and correct any issues before trying again."
        return $RET
    fi

    log_exec make -j`nproc`
    RET=$?
    if [ $RET -ne 0 ]; then
        log "There was an error building Qt. Check the log and correct any issues before trying again."
        return $RET
    fi

    log_exec sudo make install
    RET=$?
    if [ $RET -ne 0 ]; then
        log "There was an error installing Qt. Check the log and correct any issues before trying again."
        return $RET
    fi

    log "Adding Qt installation directory (/usr/local/Qt-5.5.1/) to PATH and LD_LIBRARY_PATH"
    sudo bash -c "echo export PATH=/usr/local/Qt-5.5.1/bin:$PATH >> ~/.profile"
    sudo bash -c "echo export LD_LIBRARY_PATH=/usr/local/Qt-5.5.1/lib:$LD_LIBRARY_PATH >> ~/.profile"

}

build_xtuple() {

    cd $WORKDIR
    mkdir xtuple
    cd xtuple
    git clone https://github.com/xtuple/qt-client
    cd qt-client
    GITTAG=$(curl https://api.github.com/repos/xtuple/qt-client | \
             awk -v FS='"' '/default_branch/ { print $4 }')
    if [ -z "$GITTAG" ] ; then
      GITTAG=master
    fi
    git checkout $GITTAG
    git submodule update --init --recursive
    cd openrpt
    qmake
    make -j`nproc`
    cd ../csvimp
    qmake
    make -j`nproc`
    cd ..
    qmake
    make -j`nproc`

}
