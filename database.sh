#!/bin/bash

database_menu() {

    log "Opened database menu"

    while true; do
        DBM=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title Database\ Menu )" 15 60 8 --cancel-button "Cancel" --ok-button "Select" \
            "1" "Set database info" \
            "2" "Clear database info" \
            "3" "Backup Database" \
            "4" "List Databases" \
            "5" "Rename Database" \
            "6" "Drop Database" \
            "7" "Inspect Database" \
            "8" "Carve Pilot From Existing Database" \
            "9" "Create Database From File" \
            "10" "Download Latest Demo Database" \
            "11" "Download Specific Database" \
            "12" "Upgrade xTuple Database" \
            "13" "Return to main menu" \
            3>&1 1>&2 2>&3)

        RET=$?
        if [ ${RET} -ne 0 ]; then
            break
        else
            case "${DBM}" in
            "1") log_choice clear_database_info && log_choice check_database_info ;;
            "2") log_choice clear_database_info ;;
            "3") log_choice backup_database ;;
            "4") log_choice list_databases ;;
            "5") rename_database_menu ;;
            "6") drop_database_menu ;;
            "7") inspect_database_menu ;;
            "8") log_choice carve_pilot ;;
            "9") log_choice create_database_from_file ;;
            "10") log_choice download_latest_demo ;;
            "11") log_choice download_demo manual ;;
            "12") log_choice upgrade_database ;;
            "13") main_menu ;;
            *) msgbox "How did you get here?" && break ;;
            esac
        fi
    done
}

# $1 is mode, auto (no prompt for demo location, delete when done)
# manual, prompt for location, don't delete
# $2 where to save database to
# $3 is version to grab
# $4 is type of database to grab (empty, demo, manufacturing, distribution, masterref)
download_demo() {

    if [ $1 = "manual" ]; then
        MODE="manual"
    else
        MODE="auto"
    fi

    if [ -z $4 ] && [ -z "${DBTYPE}" ]; then
        DBTYPE="demo"
    else
        DBTYPE=$4
    fi

    if [ -z $3 ]; then
        MENUVER=$(whiptail --backtitle "$( window_title )" --menu "Choose Version" 15 60 7 --cancel-button "Cancel" --ok-button "Select" \
                "1" "PostBooks 4.8.1 Demo" \
                "2" "PostBooks 4.8.1 Empty" \
                "3" "PostBooks 4.8.1 QuickStart" \
                "4" "PostBooks 4.9.5 Demo" \
                "5" "PostBooks 4.9.5 Empty" \
                "6" "PostBooks 4.9.5 QuickStart" \
                "7" "Return to database menu" \
                3>&1 1>&2 2>&3)

        RET=$?

        if [ ${RET} -ne 0 ]; then
            return ${RET}
        else
            case "${MENUVER}" in
            "1") VERSION=4.8.1
                   DBTYPE="demo"
                   ;;
            "2") VERSION=4.8.1
                   DBTYPE="empty"
                   ;;
            "3") VERSION=4.8.1
                   DBTYPE="quickstart"
                   ;;
            "4") VERSION=4.9.5
                   DBTYPE="demo"
                   ;;
            "5") VERSION=4.9.5
                   DBTYPE="empty"
                   ;;
            "6") VERSION=4.9.5
                   DBTYPE="quickstart"
                   ;;
            "7") return 0 ;;
            *) msgbox "How did you get here?" && return 1 ;;
            esac || return 1
        fi
    else
        VERSION=$3
    fi

    if [ -z $2 ]; then
        DEMODEST=$(whiptail --backtitle "$( window_title )" --inputbox "Enter the filename where you would like to save the database" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            return ${RET}
        fi
    else
        DEMODEST=$2
    fi

    log_arg ${MODE} ${DEMODEST} ${VERSION} ${DBTYPE}


    # Temporary measure to allow release candidate setup
    xtv=${VERSION}
    if [[ ${xtv} == "4.10.0-rc" ]]; then
        xtv="4.10.0RC"
    fi

    DB_URL="http://files.xtuple.org/${xtv}/${DBTYPE}.backup"
    MD5_URL="http://files.xtuple.org/${xtv}/${DBTYPE}.backup.md5sum"

    log "Saving "${DB_URL}" as "${DEMODEST}"."
    if [ ${MODE} = "auto" ]; then
        dlf_fast_console ${DB_URL} "${DEMODEST}"
        dlf_fast_console ${MD}5_URL "${DEMODEST}".md5sum
    else
        dlf_fast ${DB_URL} "Downloading Demo Database. Please Wait." "${DEMODEST}"
        dlf_fast ${MD}5_URL "Downloading MD5SUM. Please Wait." "${DEMODEST}".md5sum
    fi

    VALID=`cat "${DEMODEST}".md5sum | awk '{printf $1}'`
    CURRENT=`md5sum "${DEMODEST}" | awk '{printf $1}'`
    if [ "${VALID}" != "${CURRENT}" ]; then
        msgbox "There was an error verifying the downloaded database."
        return 1
    fi

    if [ ${MODE} = "manual" ]; then
        if (whiptail --title "Download Successful" --yesno "Download complete. Would you like to deploy this database now?" 10 60) then
            DEST=$(whiptail --backtitle "$( window_title )" --inputbox "New database name" 8 60 3>&1 1>&2 2>&3)
            RET=$?
            if [ ${RET} -ne 0 ]; then
                return ${RET}
            fi

            log "Creating database ${DEST} from file ${DEMODEST}"
            log_exec restore_database ${DEMODEST} ${DEST}
            RET=$?
            if [ ${RET} -ne 0 ]; then
                msgbox "Something has gone wrong. Check log and correct any issues."
                return 1
            else
                msgbox "Database ${DEST} successfully restored from file ${DEMODEST}"
                return 0
            fi
        else
            log "Exiting without restoring database."
            return 0
        fi
    fi

}

download_latest_demo() {

    VERSION="$( latest_version db )"
    log "Determined latest database version to be ${VERSION}"

    if [ -z "${VERSION}" ]; then
        msgbox "Could not determine latest database version"
        return 1
    fi

    if [ -z ${DEMODEST} ]; then
        DEMODEST=$(whiptail --backtitle "$( window_title )" --inputbox "Enter the filename where you would like to save the database version ${VERSION}" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            return ${RET}
        else
            export DEMODEST
        fi
    fi
    
    # Temporary measure to allow release candidate setup
    xtv=${VERSION}
    if [[ ${xtv} == "4.10.0-rc" ]]; then
        xtv="4.10.0RC"
    fi

    DB_URL="http://files.xtuple.org/${xtv}/demo.backup"
    MD5_URL="http://files.xtuple.org/${xtv}/demo.backup.md5sum"

    dlf_fast ${DB_URL} "Downloading Demo Database. Please Wait." "${DEMODEST}"
    dlf_fast ${MD}5_URL "Downloading MD5SUM. Please Wait." "${DEMODEST}".md5sum

    VALID=`cat "${DEMODEST}".md5sum | awk '{printf $1}'`
    CURRENT=`md5sum "${DEMODEST}" | awk '{printf $1}'`
    if [ "${VALID}" != "${CURRENT}" ] || [ -z "${VALID}" ]; then
        msgbox "There was an error verifying the downloaded database. Utility will now exit."
        exit
    else
        if (whiptail --title "Download Successful" --yesno "Download complete. Would you like to deploy this database now?" 10 60) then
            DEST=$(whiptail --backtitle "$( window_title )" --inputbox "New database name" 8 60 3>&1 1>&2 2>&3)
            RET=$?
            if [ ${RET} -ne 0 ]; then
                return 0
            fi
            log_exec restore_database ${DEMODEST} ${DEST}
            RET=$?
            if [ ${RET} -ne 0 ]; then
                msgbox "Something has gone wrong. Check log and correct any issues, typically warnings can be ignored."
                return ${RET}
            else
                msgbox "Database ${DEST} successfully restored from file ${DEMODEST}"
                return 0
            fi
        else
            log "Exiting without restoring database."
        fi
    fi
}

#  $1 is database file to backup to
#  $2 is name of new database (if not provided, prompt)
backup_database() {

    check_database_info
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return ${RET}
    fi

    if [ -z $1 ]; then
        DEST=$(whiptail --backtitle "$( window_title )" --inputbox "Full file name to save backup to" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            return ${RET}
        fi
    else
        DEST=$1
    fi

    if [ -z $2 ]; then
        SOURCE=$(whiptail --backtitle "$( window_title )" --inputbox "Database name to back up" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            return ${RET}
        fi
    else
        SOURCE=$2
    fi
    log_arg ${DEST} ${SOURCE}

    log "Backing up database "${SOURCE}" to file "${DEST}"."

    pg_dump --username "${PGUSER}" --port "${PGPORT}" --host "${PGHOST}" --format custom  --file "${DEST}" "${SOURCE}"
    RET=$?
    if [ ${RET} -ne 0 ]; then
        msgbox "Something has gone wrong. Check log and correct any issues."
        return ${RET}
    else
        msgbox "Database ${SOURCE} successfully backed up to ${DEST}"
        return 0
    fi
}

#  $1 is database file to restore
#  $2 is name of new database (if not provided, prompt)
restore_database() {

    check_database_info
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return ${RET}
    fi

    if [ -z $2 ]; then
        DEST=$(whiptail --backtitle "$( window_title )" --inputbox "New database name" 8 60 "${CH}" 3>&1 1>&2 2>&3)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            return ${RET}
        fi
    else
        DEST=$2
    fi

    log "Creating database ${DEST}."
    log_exec psql -h ${PGHOST} -p ${PGPORT} -U ${PGUSER} -d postgres -q -c "CREATE DATABASE "${DEST}" OWNER admin"
    RET=$?
    if [ ${RET} -ne 0 ]; then
        msgbox "Something has gone wrong. Check log and correct any issues."
        return ${RET}
    else
        log "Restoring database ${DEST} from file $1 on server ${PGHOST}:${PGPORT}"
        log_exec pg_restore --username "${PGUSER}" --port "${PGPORT}" --host "${PGHOST}" --dbname "${DEST}" "$1"
        RET=$?
        if [ ${RET} -ne 0 ]; then
            msgbox "Something has gone wrong. Check output and correct any issues."
            return ${RET}
        else
            return 0
        fi
    fi
}

# $1 is source
# $2 is new pilot
# prompt if not provided
carve_pilot() {

    check_database_info
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return ${RET}
    fi

    if [ -z "$1" ]; then
        get_database_list

        if [ -z "${DATABASES}" ]; then
            msgbox "No databases detected on this system"
            return 1
        fi

        SOURCE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to use as source for pilot" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            return ${RET}
        fi
    else
        SOURCE="$1"
    fi

    if [ -z "$2" ]; then
        PILOT=$(whiptail --backtitle "$( window_title )" --inputbox "Enter new name of database" 8 60 "" 3>&1 1>&2 2>&3)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            return ${RET}
        fi
    else
        PILOT="$2"
    fi
    log_arg ${SOURCE} ${PILOT}

    log "Creating pilot database ${PILOT} from database ${SOURCE}"
    if (whiptail --title "Warning" --yesno "This will kill all active connections to the database, if any.  Continue?" 10 60) then
        remove_connect_priv ${SOURCE}
        kill_database_connections ${SOURCE}

        log_exec psql postgres -U postgres -q -h ${PGHOST} -p ${PGPORT} -d postgres -c "CREATE DATABASE "${PILOT}" TEMPLATE "${SOURCE}" OWNER admin;"
        RET=$?
        if [ ${RET} -ne 0 ]; then
            msgbox "Something has gone wrong. Check output and correct any issues."
            restore_connect_priv ${SOURCE}
            return ${RET}
        else
            restore_connect_priv ${SOURCE}
            restore_connect_priv ${PILOT}
            msgbox "Database "${PILOT}" has been created"
        fi
    fi
}

create_database_from_file() {

    check_database_info
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return ${RET}
    fi

    SOURCE=$(whiptail --backtitle "$( window_title )" --inputbox "Enter source backup filename" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return ${RET}
    fi

    if [ ! -f ${SOURCE} ]; then
        msgbox "File "${SOURCE}" not found!"
        return 1
    fi

    PILOT=$(whiptail --backtitle "$( window_title )" --inputbox "Enter new database name" 8 60 "${CH}" 3>&1 1>&2 2>&3)
    RET=$?

    if [ ${RET} -ne 0 ]; then
        return ${RET}
    elif [ ${RET} -eq 0 ]; then
        log "Creating database ${PILOT} from file ${SOURCE}"
        restore_database ${SOURCE} ${PILOT}
        RET=$?
        if [ ${RET} -ne 0 ]; then
            msgbox "Something has gone wrong. Check log and correct any issues."
            ${RET}
        else
            msgbox "Database "${PILOT}" has been created"
        fi
    fi

}

list_databases() {

    check_database_info
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return ${RET}
    fi

    get_database_list

    if [ -z "${DATABASES}" ]; then
        msgbox "No databases detected on this system"
        return 0
    fi

    DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "List of databases on this cluster" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
}

drop_database_menu() {

    check_database_info
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return ${RET}
    fi

    get_database_list

    if [ -z "${DATABASES}" ]; then
        msgbox "No databases detected on this system"
        return 0
    fi

    DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to drop" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return ${RET}
    fi

    drop_database "${DATABASE}"

}

# $1 is name
# prompt if not provided
drop_database() {

    check_database_info
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return ${RET}
    fi

    if [ -z "$1" ]; then
        POSTNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Enter name of database to drop" 8 60 "" 3>&1 1>&2 2>&3)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            return ${RET}
        fi
    else
        POSTNAME="$1"
    fi
    log_arg ${POSTNAME}

    if (whiptail --title "Are you sure?" --yesno "Completely remove database ${POSTNAME}?" 10 60) then
        psql -qAt -U ${PGUSER} -h ${PGHOST} -p ${PGPORT} -d postgres -c "DROP DATABASE ${POSTNAME};"
        RET=$?
        if [ ${RET} -ne 0 ]; then
            msgbox "Dropping database ${POSTNAME} failed. Please check the output and correct any issues."
            return ${RET}
        else
            msgbox "Dropping database ${POSTNAME} successful"
        fi
    else
        return 0
    fi

}

rename_database_menu() {

    check_database_info
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return ${RET}
    fi

    get_database_list

    if [ -z "${DATABASES}" ]; then
        msgbox "No databases detected on this system"
        return 0
    fi

    SOURCE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to rename" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return 0
    fi

    DEST=$(whiptail --backtitle "$( window_title )" --inputbox "Enter new database name" 8 60 "" 3>&1 1>&2 2>&3)
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return 0
    fi

    rename_database "${SOURCE}" "${DEST}"

}

# $1 is source
# $2 is new name
# prompt if not provided
rename_database() {

    if [ -z "$1" ]; then
        SOURCE=$(whiptail --backtitle "$( window_title )" --inputbox "Enter name of database to rename" 8 60 "" 3>&1 1>&2 2>&3)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            return ${RET}
        fi
    else
        SOURCE="$1"
    fi

    if [ -z "$2" ]; then
        DEST=$(whiptail --backtitle "$( window_title )" --inputbox "Enter new name of database" 8 60 "" 3>&1 1>&2 2>&3)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            return ${RET}
        fi
    else
        DEST="$2"
    fi
    log_arg ${SOURCE} ${DEST}

    log_exec psql -qAt -U ${PGUSER} -h ${PGHOST} -p ${PGPORT} -d postgres -c "ALTER DATABASE ${SOURCE} RENAME TO ${DEST};"
    RET=$?
    if [ ${RET} -ne 0 ]; then
        msgbox "Renaming database ${SOURCE} failed. Please check the output and correct any issues."
        return ${RET}
    else
        msgbox "Successfully renamed database ${SOURCE} to ${DEST}"
    fi

}

inspect_database_menu() {

    check_database_info
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return ${RET}
    fi

    get_database_list

    if [ -z "${DATABASES}" ]; then
        msgbox "No databases detected on this system"
        return 0
    fi

    DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to inspect" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return 0
    fi

    inspect_database "${DATABASE}"

}

get_database_list() {

    check_database_info

    DATABASES=()
    while read -r line; do
        DATABASES+=("${line}" "${line}")
    done < <( psql -At -U ${PGUSER} -h ${PGHOST} -p ${PGPORT} -d postgres -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1');" )
}

# $1 is database name
remove_connect_priv() {

    check_database_info
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return ${RET}
    fi

    log_exec psql -At -U postgres -h ${PGHOST} -p ${PGPORT} -d postgres -c "REVOKE CONNECT ON DATABASE "$1" FROM public, admin, xtrole;"
}

# $1 is database name
kill_database_connections() {

    check_database_info
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return ${RET}
    fi

    log_exec psql -At -U postgres -h ${PGHOST} -p ${PGPORT} -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='"$1"';"
}

# $1 is database name
restore_connect_priv() {

    check_database_info
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return ${RET}
    fi

    log_exec psql -At -U postgres -h ${PGHOST} -p ${PGPORT} -d postgres -c "GRANT CONNECT ON DATABASE "$1" TO public, admin, xtrole;"
}

# $1 is database name to inspect
inspect_database() {

    VAL=`psql -At -U ${PGUSER} -h ${PGHOST} -p ${PGPORT} -d $1 -c "SELECT data FROM ( \
        SELECT 1,'Co: '||fetchmetrictext('remitto_name') AS data \
        UNION \
        SELECT 2,'Ap: '||fetchmetrictext('Application')||' v'||fetchmetrictext('ServerVersion') \
        UNION \
        SELECT 3,'Pk: '||pkghead_name||' v'||pkghead_version \
        FROM pkghead) as dummy ORDER BY 1;"`

    msgbox "${VAL}"
    log_arg $1

}

set_database_info_select() {
    CLUSTERS=()

    while read -r line; do 
        CLUSTERS+=("${line}" "${line}")
    done < <( sudo pg_lsclusters | tail -n +2 )

     if [ -z "${CLUSTERS}" ]; then
        msgbox "No database clusters detected on this system"
        return 1
    fi

    CLUSTER=$(whiptail --title "xTuple Utility v${_REV}" --menu "Select cluster to use" 16 120 5 "${CLUSTERS[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return ${RET}
    fi

    if [ -z "${CLUSTER}" ]; then
        msgbox "No database clusters detected on this system"
        return 1
    fi

    export PGVER=`awk  '{print $1}' <<< "${CLUSTER}"`
    export PGNAME=`awk  '{print $2}' <<< "${CLUSTER}"`
    export PGPORT=`awk  '{print $3}' <<< "${CLUSTER}"`
    export PGHOST=localhost
    export PGUSER=postgres

    PGPASSWORD=$(whiptail --backtitle "$( window_title )" --passwordbox "Enter postgres user password" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ ${RET} -ne 0 ]; then
        return ${RET}
    else
        export PGPASSWORD
    fi

    if [ -z "${PGVER}" ] || [ -z "${PGNAME}" ] || [ -z "${PGPORT}" ]; then
        msgbox "Could not determine database version or name"
        return 0
    fi
}

set_database_info_manual() {

    if [ -z ${PGHOST} ]; then
        PGHOST=$(whiptail --backtitle "$( window_title )" --inputbox "Hostname" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            unset PGHOST && unset PGPORT && unset PGUSER && unset PGPASSWORD
            return ${RET}
        else
            export PGHOST
        fi
    fi
    if [ -z ${PGPORT} ] ; then
        PGPORT=$(whiptail --backtitle "$( window_title )" --inputbox "Port" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            unset PGHOST && unset PGPORT && unset PGUSER && unset PGPASSWORD
            return ${RET}
        else
            export PGPORT
        fi
    fi
    if [ -z ${PGUSER} ] ; then
        PGUSER=$(whiptail --backtitle "$( window_title )" --inputbox "Username" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            unset PGHOST && unset PGPORT && unset PGUSER && unset PGPASSWORD
            return ${RET}
        else
            export PGUSER
        fi
    fi
    if [ -z ${PGPASSWORD} ] ; then
        PGPASSWORD=$(whiptail --backtitle "$( window_title )" --passwordbox "Password" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            unset PGHOST && unset PGPORT && unset PGUSER && unset PGPASSWORD
            return ${RET}
        else
            export PGPASSWORD
        fi
    fi

}

clear_database_info() {
    unset PGHOST
    unset PGPASSWORD
    unset PGPORT
    unset PGUSER
}

check_database_info() {
    if [ -z ${PGHOST} ] || [ -z ${PGPORT} ] || [ -z ${PGUSER} ] || [ -z ${PGPASSWORD} ]; then
        if (whiptail --yes-button "Select Cluster" --no-button "Manually Enter"  --yesno "Would you like to choose from installed clusters, or manually enter server information?" 10 60) then
            set_database_info_select
            RET=$?
            return ${RET}
        else
            # I specifically need to check for ESC here as I am using the yesno box as a multiple choice question, 
            # so it chooses no code even during escape which in this case I want to actually escape when someone hits escape. 
            if [ $? -eq 255 ]; then
                return 255
            fi
            set_database_info_manual
            RET=$?
            return ${RET}
        fi
    else
        return 0
    fi
}

# $1 is database
upgrade_database() {

    check_database_info

    if [ -z "${UPDATEREXEC}" ]; then
        UPDATEREXEC=$(whiptail --backtitle "$( window_title )" --inputbox "Auto updater executable location" 8 60 ${HOME}/updater/utilities/AutoUpdate/xtuple_autoupdater 3>&1 1>&2 2>&3)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            return ${RET}
        fi
	   export UPDATEREXEC
    fi

    if [ -z "${UPDATEPKGS}" ]; then
        UPDATEPKGS=$(whiptail --backtitle "$( window_title )" --inputbox "Updater packages directory" 8 60 ${HOME}/Updater/pkgs 3>&1 1>&2 2>&3)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            return ${RET}
        fi
	   log_exec mkdir -p ${UPDATEPKGS}
	   export UPDATEPKGS
    fi

    if [ -z "$1" ]; then
        DATABASES=()
	   VERSIONS=()
	   APPLICATIONS=()

        while read -r line; do
            DATABASES+=("${line}")
		  VER=`psql -At -U ${PGUSER} -p ${PGPORT} -d ${line} -c "SELECT fetchmetrictext('ServerVersion') AS application;"`
		  APP=`psql -At -U ${PGUSER} -p ${PGPORT} -d ${line} -c "SELECT fetchmetrictext('Application') AS application;"`
		  VERSIONS+=("${VER}")
		  APPLICATIONS+=("${APP}")
         done < <( psql -At -h ${PGHOST} -p ${PGPORT} -d postgres -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1');" )
         if [ -z "${DATABASES}" ]; then
            msgbox "No databases detected on this system"
            return 0
        fi

        CHOICE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to upgrade" 16 60 5 --cancel-button "Cancel" --ok-button "Select" \
	   $(paste -d '\n' \
	   <(seq 0 $((${#DATABASES[@]}-1))) \
        <(echo ${DATABASES[*]} | tr ' ' '\n')) \
	   3>&1 1>&2 2>&3)
        RET=$?
        if [ ${RET} -ne 0 ]; then
            return 0
        fi
	   DATABASE=${DATABASES[${CHOICE}]}
    else
        DATABASE="$1"
    fi

    log "Detected application ${APPLICATIONS[${CHOICE}]}"
    log "Detected server version ${VERSIONS[${CHOICE}]}"
    UPS=`curl -s 'http://api.xtuple.org/upgradepath.php?package='${APPLICATIONS[${CHOICE}]}'&fromver='${VERSIONS[${CHOICE}]} | grep -oP 'http\S+' | sed 's/<.*//'`
    log "Detected upgrades ${UPS[*]}"

    if ! (whiptail --title "Database Selected" --yesno "Database: ${DATABASE}\nApplication: ${APPLICATIONS[${CHOICE}]}\nVersion: ${VERSIONS[${CHOICE}]}\nWould you like to upgrade this database now?" 10 60) then
        return 0
    fi

    # download the upgrade packages
    for pack in ${UPS[*]} ; do
        packname=$(echo ${pack} | sed 's#.*/##'g)
        dlf_fast ${pack} ${packname} ${UPDATEPKGS}/${packname}
    done

    msgbox "All Packages Downloaded"

    # Start up the virtual framebuffer to use for the updater
    if [ ! -e /tmp/.X99-lock ]; then
        log_exec start-stop-daemon --start -b -x /usr/bin/Xvfb :99
        export DISPLAY=:99
    fi

    # make sure plv8 is in
    log_exec psql -At -U ${PGUSER} -p ${PGPORT} -d ${DATABASE} -c "create EXTENSION IF NOT EXISTS plv8;"

    # run the updater
    log_exec bash ${UPDATEREXEC} -l ${UPDATEPKGS} ${PGHOST}:${PGPORT}/${DATABASE}

    # display results
    NEWVER=`psql -At -U ${PGUSER} -p ${PGPORT} -d ${DATABASE} -c "SELECT fetchmetrictext('ServerVersion') AS application;"`
    msgbox "Database ${DATABASE}\nVersion ${NEWVER}"

    log_arg ${DATABASE}
}
