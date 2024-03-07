#!/bin/bash

cur_dir=$(pwd)

# check (root) user
[[ $EUID -ne 0 ]] && echo -e "(must) use (root) (user) to run this script！\n" && exit 1

# check (operating system)
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

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64"
elif [[ $arch == "riscv64" ]]; then
    arch="riscv64"
else
    arch="amd64"
    echo -e "(failed) to detect (architecture), using (default) (architecture): ${arch}"
fi

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "This software does not support 32-bit systems (x86), please use 64-bit systems (x86_64/arm64/riscv64) or compile it yourself"
    exit 2
fi

if [[ $arch == "amd64" ]]; then
    if lscpu | grep -Eqi "avx2"; then
        release="amd64v3"
    fi
fi

echo "(architecture): ${arch}"

os_version=""

# (operating system) version
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

install_base() {
    if [[ x"${release}" == x"rhel" ]]; then
        dnf install epel-release -y
        dnf install wget curl unzip tar crontabs -y
    else
        apt update -y
        apt install wget curl unzip tar cron -y
    fi
}

# 0: (running), 1: (not running), 2: (not installed)
check_status() {
    if [[ ! -f /etc/systemd/system/uim-server.service ]]; then
        return 2
    temp=$(systemctl status uim-server | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)

    if [[ x"${temp}" == x"(running)" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
}

install_uim_server() {
  if [[ -e /usr/local/uim-server/ ]]; then
      rm /usr/local/uim-server/ -rf
  fi

  mkdir /usr/local/uim-server/ -p
        cd /usr/local/uim-server/

  if  [ $# == 0 ] ;then
      last_version=$(curl -Ls "https://api.github.com/repos/SSPanel-UIM/UIM-Server/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
      if [[ ! -n "$last_version" ]]; then
          echo -e "(failed) to detect uim-server version, may be exceeded Github API limit, please try again later, or manually specify uim-server version to install"
          exit 1
      fi
      echo -e "(detected) latest uim-server version: ${last_version}, starting installation"
      wget -q -O /usr/local/uim-server/uim-server-linux.zip https://github.com/SSPanel-UIM/UIM-Server/releases/download/${last_version}/uim-server-linux-${arch}.zip
      if [[ $? -ne 0 ]]; then
          echo -e "(failed) to download uim-server, please make sure your server can download files from Github"
          exit 1
      fi
  else
      if [[ $1 == v* ]]; then
          last_version=$1
      else
                last_version="v"$1
            fi
      url="https://github.com/SSPanel-UIM/UIM-Server/releases/download/${last_version}/uim-server-linux-${arch}.zip"
      echo -e "Starting installation of uim-server ${last_version}"
      wget -q -O /usr/local/uim-server/uim-server-linux.zip ${url}
      if [[ $? -ne 0 ]]; then
          echo -e "(failed) to download uim-server ${last_version}, please make sure this version exists"
          exit 1
      fi
  fi

  unzip uim-server-linux.zip
  rm uim-server-linux.zip -f
  chmod +x uim-server
  mkdir /etc/uim-server/ -p
  rm /etc/systemd/system/uim-server.service -f
  file="https://github.com/SSPanel-UIM/mirror/raw/main/uim-server/uim-server.service"
  wget -q -O /etc/systemd/system/uim-server.service ${file}
  systemctl daemon-reload
  systemctl stop uim-server
  systemctl enable uim-server
  echo -e "uim-server ${last_version} installation completed, auto-start set on boot"
  cp geoip.dat /etc/uim-server/
  cp geosite.dat /etc/uim-server/

  if [[ ! -f /etc/uim-server/config.yml ]]; then
      cp config.yml /etc/uim-server/
  else
      systemctl start uim-server
      sleep 2
      check_status
      echo -e ""
      if [[ $? == 0 ]]; then
          echo -e "uim-server (restarted) successfully"
      else
          echo -e "uim-server (failed) to start"
      fi
  fi

  if [[ ! -f /etc/uim-server/dns.json ]]; then
      cp dns.json /etc/uim-server/
  fi
  if [[ ! -f /etc/uim-server/route.json ]]; then
      cp route.json /etc/uim-server/
  fi
  if [[ ! -f /etc/uim-server/custom_outbound.json ]]; then
      cp custom_outbound.json /etc/uim-server/
  fi
  if [[ ! -f /etc/uim-server/custom_inbound.json ]]; then
      cp custom_inbound.json /etc/uim-server/
  fi
  if [[ ! -f /etc/uim-server/rulelist ]]; then
      cp rulelist /etc/uim-server/
  fi

  curl -o /usr/bin/uim-server -Ls https://github.com/SSPanel-UIM/UIM-Server/raw/main/release/uim-server.sh
  chmod +x /usr/bin/uim-server
  cd $cur_dir
  rm -f install.sh
  echo -e ""
  echo "How to use UIM-Server management script: "
  echo "---------------------------------------------"
  echo "uim-server - show management menu (more functions)"
  echo "uim-server start - Start UIM-Server"
  echo "uim-server stop - Stop UIM-Server"
  echo "uim-server restart - Restart UIM-Server"
  echo "uim-server status - View UIM-Server status"
  echo "uim-server enable - Set UIM-Server to start automatically at boot"
  echo "uim-server disable - Cancel UIM-Server startup at boot"
  echo "uim-server log - View UIM-Server log"
  echo "uim-server update - Update UIM-Server"
  echo "uim-server update x.x.x - Update UIM-Server specified version"
  echo "uim-server config - display configuration file contents"
  echo "uim-server install - Install UIM-Server"
  echo "uim-server uninstall - Uninstall UIM-Server"
  echo "uim-server version - View UIM-Server version"
  echo "---------------------------------------------"
}

echo -e "开始安装"
install_base
# install_acme
install_uim_server $1
