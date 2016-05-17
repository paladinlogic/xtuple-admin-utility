#!/bin/bash

mwc_menu() {

    log "Opened Web Client menu"

    while true; do
        PGM=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title Web\ Client\ Menu )" 0 0 9 --cancel-button "Cancel" --ok-button "Select" \
            "1" "Install xTuple Web Client" \
            "2" "Remove xTuple Web Client" \
            "3" "Return to main menu" \
            3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -ne 0 ]; then
            break
        else
            case "$PGM" in
            "1") install_mwc_menu ;;
            "2") log_choice remove_mwc ;;
            "3") break ;;
            *) msgbox "Error. How did you get here? >> mwc_menu / $PGM" && break ;;
            esac
        fi
    done

}

install_mwc_menu() {

    TAGVERSIONS=$(git ls-remote --tags git://github.com/xtuple/xtuple.git | grep -v '{}' | cut -d '/' -f 3 | cut -d v -f2 | sort -rV | head -10)
    HEADVERSIONS=$(git ls-remote --heads git://github.com/xtuple/xtuple.git | grep -Po '\d_\d+_x' | sort -rV | head -5)

    MENUVER=$(whiptail --backtitle "$( window_title )" --menu "Choose Web Client Version" 15 60 7 --cancel-button "Exit" --ok-button "Select" \
        $(paste -d '\n' \
        <(seq 0 9) \
        <(echo $TAGVERSIONS | tr ' ' '\n')) \
        $(paste -d '\n' \
        <(seq 10 14) \
        <(echo $HEADVERSIONS | tr ' ' '\n')) \
        "15" "Return to main menu" \
        3>&1 1>&2 2>&3)

    RET=$?

    if [ $RET -eq 0 ]; then
        if [ $MENUVER -eq 16 ]; then
            return 0;
        elif [ $MENUVER -lt 10 ]; then
            read -a tagversionarray <<< $TAGVERSIONS
            MWCVERSION=${tagversionarray[$MENUVER]}
            MWCREFSPEC=v$MWCVERSION
        else
            read -a headversionarray <<< $HEADVERSIONS
            MWCVERSION=${headversionarray[(($MENUVER-10))]}
            MWCREFSPEC=$MWCVERSION
        fi
    else
        return $RET
    fi

    log "Chose version $MWCVERSION"

    MWCNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Enter a name for this xTuple instance" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    log "Chose mobile name $MWCNAME"

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    DATABASES=()

    while read -r line; do
        DATABASES+=("$line" "$line")
     done < <( psql -At -U $PGUSER -h $PGHOST -p $PGPORT -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1');" )
     if [ -z "$DATABASES" ]; then
        msgbox "No databases detected on this system"
        return 1
    fi

    DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "List of databases on this cluster" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
        log "There was an error selecting the database.. exiting"
        return $RET
    fi

    log "Chose database $DATABASE"

    if (whiptail --title "Private Extensions" --yesno "Would you like to install the commercial extensions? You will need a commercial database or this step will fail." 10 60) then
        log "Installing the commercial extensions"
        PRIVATEEXT=true
        GITHUBNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Enter your GitHub username" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi

        GITHUBPASS=$(whiptail --backtitle "$( window_title )" --passwordbox "Enter your GitHub password" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi
    else
        log "Not installing the commercial extensions"
        PRIVATEEXT=false
    fi

    log_choice install_mwc $MWCVERSION $MWCREFSPEC $MWCNAME $PRIVATEEXT $DATABASE $GITHUBNAME $GITHUBPASS
}


# $1 is xtuple version
# $2 is the git refspec
# $3 is the instance name
# $4 is to install private extensions
# $5 is database name
# $6 is github username
# $7 is github password
install_mwc() {

    log "installing web client"

    export MWCVERSION=$1
    export MWCREFSPEC=$2
    export MWCNAME="$3"

    if [ -z "$4" ] || [ ! "$4" = "true" ]; then
        PRIVATEEXT=false
    else
        PRIVATEEXT=true
    fi
    
    if [ -z "$5" ] && [ -z "$PGDATABASE" ]; then
        log "No database name passed to install_mwc... exiting."
        do_exit
    else
        PGDATABASE=$5
    fi

    export GITHUBNAME=$6
    export GITHUBPASS=$7
    log_arg $MWCVERSION $MWCNAME $PRIVATEEXT $PGDATABASE

    log "Creating xtuple user..."
    log_exec sudo useradd xtuple -m -s /bin/bash

    log "Installing n..."
    cd $WORKDIR    
    wget https://raw.githubusercontent.com/visionmedia/n/master/bin/n -qO n
    log_exec chmod +x n
    log_exec sudo mv n /usr/bin/n
    # use it to set node to 0.10
    log "Installing node 0.10.40..."
    log_exec sudo n 0.10.40

    # need to install npm of course...why doesn't 2.3.14 exist?
    log_exec sudo npm install -g npm@1.4.28

    # cleanup existing folder or git will throw a hissy fit
    sudo rm -rf /opt/xtuple/$MWCVERSION/"$MWCNAME"

    log "Cloning xTuple Web Client Source Code to /opt/xtuple/$MWCVERSION/xtuple"
    log "Using version $MWCVERSION with the given name $MWCNAME"
    log_exec sudo mkdir -p /opt/xtuple/$MWCVERSION/"$MWCNAME"
    log_exec sudo chown -R xtuple.xtuple /opt/xtuple

    # main code
    log_exec sudo su - xtuple -c "cd /opt/xtuple/$MWCVERSION/"$MWCNAME" && git clone https://github.com/xtuple/xtuple.git && cd  /opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple && git checkout $MWCREFSPEC && git submodule update --init --recursive && npm install bower && npm install"
    # private extensions
    if [ $PRIVATEEXT = "true" ]; then
        log "Installing the commercial extensions"
        log_exec sudo su xtuple -c "cd /opt/xtuple/$MWCVERSION/"$MWCNAME" && git clone https://"$GITHUBNAME":"$GITHUBPASS"@github.com/xtuple/private-extensions.git && cd /opt/xtuple/$MWCVERSION/"$MWCNAME"/private-extensions && git checkout $MWCREFSPEC && git submodule update --init --recursive && npm install"
    else
        log "Not installing the commercial extensions"
    fi

    if [ ! -f /opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple/node-datasource/sample_config.js ]; then
        log "Hrm, sample_config.js doesn't exist.. something went wrong. check the output/log and try again"
        do_exit
    fi

    export XTDIR=/opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple

    sudo rm -rf /etc/xtuple/$MWCVERSION/"$MWCNAME"
    log_exec sudo mkdir -p /etc/xtuple/$MWCVERSION/"$MWCNAME"/private

    # setup encryption details
    log_exec sudo touch /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/salt.txt
    log_exec sudo touch /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/encryption_key.txt
    log_exec sudo chown -R xtuple.xtuple /etc/xtuple/$MWCVERSION/"$MWCNAME"
    # temporarily so we can cat to them since bash is being a bitch about quoting the trim string below
    log_exec sudo chmod 777 /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/encryption_key.txt
    log_exec sudo chmod 777 /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/salt.txt

    cat /dev/urandom | tr -dc '0-9a-zA-Z!@#$%^&*_+-'| head -c 64 > /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/salt.txt
    cat /dev/urandom | tr -dc '0-9a-zA-Z!@#$%^&*_+-'| head -c 64 > /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/encryption_key.txt

    log_exec sudo chmod 660 /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/encryption_key.txt
    log_exec sudo chmod 660 /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/salt.txt

    log_exec sudo openssl genrsa -des3 -out /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/server.key -passout pass:xtuple 1024
    log_exec sudo openssl rsa -in /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/server.key -passin pass:xtuple -out /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/key.pem -passout pass:xtuple
    log_exec sudo openssl req -batch -new -key /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/key.pem -out /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/server.csr -subj '/CN='$(hostname)
    log_exec sudo openssl x509 -req -days 365 -in /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/server.csr -signkey /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/key.pem -out /etc/xtuple/$MWCVERSION/"$MWCNAME"/private/server.crt

    log_exec sudo cp /opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple/node-datasource/sample_config.js /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js

    log_exec sudo sed -i  "/encryptionKeyFile/c\      encryptionKeyFile: \"/etc/xtuple/$MWCVERSION/"$MWCNAME"/private/encryption_key.txt\"," /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js
    log_exec sudo sed -i  "/keyFile/c\      keyFile: \"/etc/xtuple/$MWCVERSION/"$MWCNAME"/private/key.pem\"," /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js
    log_exec sudo sed -i  "/certFile/c\      certFile: \"/etc/xtuple/$MWCVERSION/"$MWCNAME"/private/server.crt\"," /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js
    log_exec sudo sed -i  "/saltFile/c\      saltFile: \"/etc/xtuple/$MWCVERSION/"$MWCNAME"/private/salt.txt\"," /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js

    log "Using database $PGDATABASE"
    log_exec sudo sed -i  "/databases:/c\      databases: [\"$PGDATABASE\"]," /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js
    log_exec sudo sed -i  "/port: 5432/c\      port: \"$PGPORT\"," /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js

    log_exec sudo chown -R xtuple.xtuple /etc/xtuple

    if [ $DISTRO = "ubuntu" ]; then
        case "$CODENAME" in
            "trusty") ;&
            "utopic") 
                log "Creating upstart script using filename /etc/init/xtuple-$MWCNAME.conf"
                # create the upstart script
                sudo cp $WORKDIR/templates/ubuntu-upstart /etc/init/xtuple-"$MWCNAME".conf
                log_exec sudo bash -c "echo \"chdir /opt/xtuple/$MWCVERSION/\"$MWCNAME\"/xtuple/node-datasource\" >> /etc/init/xtuple-\"$MWCNAME\".conf"
                log_exec sudo bash -c "echo \"exec ./main.js -c /etc/xtuple/$MWCVERSION/\"$MWCNAME\"/config.js > /var/log/node-datasource-$MWCVERSION-\"$MWCNAME\".log 2>&1\" >> /etc/init/xtuple-\"$MWCNAME\".conf"
                ;;
            "vivid")
                log "Creating systemd service unit using filename /etc/systemd/system/xtuple-$MWCNAME.service"
                sudo cp $WORKDIR/templates/xtuple-systemd.service /etc/systemd/system/xtuple-"$MWCNAME".service
                log_exec sudo bash -c "echo \"SyslogIdentifier=xtuple-$MWCNAME\" >> /etc/systemd/system/xtuple-\"$MWCNAME\".service"
                log_exec sudo bash -c "echo \"ExecStart=/usr/local/bin/node /opt/xtuple/$MWCVERSION/\"$MWCNAME\"/xtuple/node-datasource/main.js -c /etc/xtuple/$MWCVERSION/\"$MWCNAME\"/config.js\" >> /etc/systemd/system/xtuple-\"$MWCNAME\".service"
                ;;
        esac
    elif [ $DISTRO = "debian" ]; then
        case "$CODENAME" in
            "wheezy")
                log "Creating debian init script using filename /etc/init.d/xtuple-$MWCNAME"
                # create the weird debian sysvinit style script
                sudo cp $WORKDIR/templates/debian-init /etc/init.d/xtuple-"$MWCNAME"
                log_exec sudo sed -i  "/APP_DIR=/c\APP_DIR=\"/opt/xtuple/$MWCVERSION/"$MWCNAME"/xtuple/node-datasource\"" /etc/init.d/xtuple-"$MWCNAME"
                log_exec sudo sed -i  "/CONFIG_FILE=/c\CONFIG_FILE=\"/etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js\"" /etc/init.d/xtuple-"$MWCNAME"
                # should be +x from git but just in case...
                sudo chmod +x /etc/init.d/xtuple-"$MWCNAME"
                ;;
            "jessie")
                log "Creating systemd service unit using filename /etc/systemd/system/xtuple-$MWCNAME.service"
                sudo cp $WORKDIR/templates/xtuple-systemd.service /etc/systemd/system/xtuple-"$MWCNAME".service
                log_exec sudo bash -c "echo \"SyslogIdentifier=xtuple-$MWCNAME\" >> /etc/systemd/system/xtuple-\"$MWCNAME\".service"
                log_exec sudo bash -c "echo \"ExecStart=/usr/local/bin/node /opt/xtuple/$MWCVERSION/\"$MWCNAME\"/xtuple/node-datasource/main.js -c /etc/xtuple/$MWCVERSION/\"$MWCNAME\"/config.js\" >> /etc/systemd/system/xtuple-\"$MWCNAME\".service"
                ;;
        esac
    else
        log "Seriously? We made it all the way to where I need to write out the init script and suddenly I can't detect your distro -> $DISTRO codename -> $CODENAME"
        do_exit
    fi

    log_exec sudo su - xtuple -c "cd $XTDIR && ./scripts/build_app.js -c /etc/xtuple/$MWCVERSION/"$MWCNAME"/config.js"
    RET=$?
    if [ $RET -ne 0 ]; then
        log "buildapp failed to run. Check output and try again"
        do_exit
    fi

    # now that we have the script, start the server!
    if [ $DISTRO = "ubuntu" ]; then
        case "$CODENAME" in
            "trusty") ;&
            "utopic") 
                log_exec sudo service xtuple-"$MWCNAME" start
                ;;
            "vivid")
                log_exec sudo systemctl enable xtuple-"$MWCNAME".service
                log_exec sudo systemctl start xtuple-"$MWCNAME".service
                ;;
        esac
    elif [ $DISTRO = "debian" ]; then
        case "$CODENAME" in
            "wheezy")
                log_exec sudo /etc/init.d/xtuple-"$MWCNAME" start
                ;;
            "jessie")
                log_exec sudo systemctl enable xtuple-"$MWCNAME".service
                log_exec sudo systemctl start xtuple-"$MWCNAME".service
                ;;
        esac
    else
        log "Seriously? We made it all the way to where I need to start the server and suddenly I can't detect your distro -> $DISTRO codename -> $CODENAME"
        do_exit
    fi

    # assuming etho for now... hostname -I will give any non-local address if we wanted
    IP=`ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1`
    log "All set! You should now be able to log on to this server at https://$IP:8443 with username admin and password admin. Make sure you change your password!"

}

remove_mwc() {
    msgbox "Uninstalling the mobile client is not yet supported"
}
