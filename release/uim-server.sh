#!/bin/bash

version="v1.0.0"

# check (root) user
[[ $EUID -ne 0 ]] && echo -e "(must) use (root) (user) to run this script！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat|rocky|alma|fedora"; then
    release="rhel"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat|rocky|alma|fedora"; then
    release="rhel"
else
    echo -e "(not detected) system version！\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"rhel" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "Please use CentOS 8 or higher version of the system！\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 20 ]]; then
        echo -e "Please use Ubuntu 20 or higher version of the system！\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 10 ]]; then
        echo -e "Please use Debian 10 or higher version of the system！\n" && exit 1
    fi
fi

confirm() {
    if [[ $# -gt 1 ]]; then
        echo && read -p "$1 [default$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Whether to restart UIM-Server" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "Press enter to return to main menu: " && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://github.com/SSPanel-UIM/UIM-Server/raw/main/release/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "Enter specified version (default latest version): " && read version
    else
        version=$2
    fi
    
    bash <(curl -Ls https://github.com/SSPanel-UIM/UIM-Server/raw/main/release/install.sh) $version
    
    if [[ $?== 0 ]]; then
        echo -e "Update completed, UIM-Server has been automatically restarted, please use UIM-Server log to view the running log"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "UIM-Server will automatically attempt to restart after modifying the configuration"
    vi /etc/uim-server/config.yml
    sleep 2
    check_status
    case $? in
        0)
            echo -e "UIM-Server status: Running"
            ;;
        1)
            echo -e "Detected that you did not start UIM-Server or UIM-Server failed to restart automatically, do you want to view the log? [Y/n]" && echo
            read -e -p "(default: y):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "UIM-Server status: Not installed"
    esac
}

uninstall() {
    confirm "Are you sure you want to uninstall UIM-Server?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop uim-server
    systemctl disable uim-server
    rm /etc/systemd/system/uim-server.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/uim-server/ -rf
    rm /usr/local/uim-server/ -rf

    echo ""
    echo -e "Uninstallation successful, if you want to delete this script, exit the script and run rm /usr/bin/uim-server -f to delete it"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "UIM-Server (is running), no need to start again, please choose (restart) if you need to restart"
    else
        systemctl start uim-server
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "UIM-Server (started) successfully, please use 'UIM-Server log' to view the running log"
        else
            echo -e "UIM-Server may have (failed) to start, please check the log information later using 'UIM-Server log'"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop uim-server
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "UIM-Server (stopped) successfully"
    else
        echo -e "UIM-Server (failed) to stop, possibly because the stop time exceeded two seconds, please check the log information later"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart uim-server
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "UIM-Server (restarted) successfully, please use 'UIM-Server log' to view the running log"
    else
        echo -e "UIM-Server may have (failed) to start, please check the log information later using 'UIM-Server log'"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status uim-server --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable uim-server
    if [[ $? == 0 ]]; then
        echo -e "UIM-Server (set) auto-start on boot successfully"
    else
        echo -e "UIM-Server (failed) to set auto-start on boot"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable uim-server
    if [[ $? == 0 ]]; then
        echo -e "UIM-Server (cancelled) auto-start on boot successfully"
    else
        echo -e "UIM-Server (failed) to cancel auto-start on boot"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u uim-server.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

update_shell() {
    wget -q -O /usr/bin/uim-server https://github.com/SSPanel-UIM/UIM-Server/raw/main/release/uim-server.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "(failed) to download script, please check if this machine can connect to Github"
        before_show_menu
    else
        chmod +x /usr/bin/uim-server
        echo -e "Script (upgraded) successfully, please run the script again" && exit 0
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/uim-server.service ]]; then
        return 2
    fi
    temp=$(systemctl status uim-server | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

check_enabled() {
    temp=$(systemctl is-enabled uim-server)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "UIM-Server (is installed), please do not install again"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "Please install UIM-Server first"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "UIM-Server status: (running)"
            show_enable_status
            ;;
        1)
            echo -e "UIM-Server status: (not running)"
            show_enable_status
            ;;
        2)
            echo -e "UIM-Server status: (not installed)"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Auto-start on boot: Yes"
    else
        echo -e "Auto-start on boot: No"
    fi
}

show_uim_server_version() {
    echo -n "UIM-Server version:"
    /usr/local/UIM-Server/UIM-Server --version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_usage() {
    echo "UIM-Server management script usage: "
    echo "------------------------------------------"
    echo "uim-server                    - (show) management menu (more features)"
    echo "uim-server start              - (start) UIM-Server"
    echo "uim-server stop               - (stop) UIM-Server" 
    echo "uim-server restart            - (restart) UIM-Server"
    echo "uim-server status             - (view) UIM-Server status"
    echo "uim-server enable             - (set) UIM-Server to auto-start on boot"
    echo "uim-server disable            - (cancel) UIM-Server auto-start on boot"
    echo "uim-server log                - (view) UIM-Server log"
    echo "uim-server update             - (update) UIM-Server"
    echo "uim-server update x.x.x       - (update) UIM-Server to specified version" 
    echo "uim-server config             - (show) configuration file content"
    echo "uim-server install            - (install) UIM-Server"
    echo "uim-server uninstall          - (uninstall) UIM-Server"
    echo "uim-server version            - (view) UIM-Server version"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
--- https://github.com/SSPanel-UIM/UIM-Server ---
  0. (modify) configuration 
————————————————
  1. (install) UIM-Server
  2. (update) UIM-Server
  3. (uninstall) UIM-Server
————————————————
  4. (start) UIM-Server
  5. (stop) UIM-Server
  6. (restart) UIM-Server
  7. (view) UIM-Server status
  8. (view) UIM-Server log
————————————————
  9. (set) UIM-Server auto-start on boot
 10. (cancel) UIM-Server auto-start on boot
————————————————
 12. (view) UIM-Server version
 13. (upgrade) maintenance script
 "
 #Subsequent updates can be added to the above string
    show_status
    echo && read -p "Please enter your choice [0-13]: " num

    case "${num}" in
        0) config
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && start
        ;;
        5) check_install && stop
        ;;
        6) check_install && restart
        ;;
        7) check_install && status
        ;;
        8) check_install && show_log
        ;;
        9) check_install && enable
        ;;
        10) check_install && disable
        ;;
        11) install_bbr
        ;;
        12) check_install && show_uim_server_version
        ;;
        13) update_shell
        ;;
        *) echo -e "Please enter the correct number [0-12]"
        ;;
    esac
}


if [[ $# -gt 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0 $2
        ;;
        "config") config $*
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        "version") check_install 0 && show_uim_server_version 0
        ;;
        "update_shell") update_shell
        ;;
        *) show_usage
    esac
else
    show_menu
fi
