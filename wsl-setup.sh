#!/usr/bin/env bash
#
# wsl-setup.sh

function check_os() {
  # Try to discover the OS flavor 
  if [[ -f /etc/os-release ]]; then
    # freedesktop.org and systemd 
    # shellcheck disable=SC1091
    . /etc/os-release
    OS="${NAME}"
    VER="${VERSION_ID}"
  elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS="$(lsb_release -si)"
    VER="$(lsb_release -sr)"
  elif [[ -f /etc/lsb-release ]]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    # shellcheck disable=SC1091
    . /etc/lsb-release
    OS="${DISTRIB_ID}"
    VER="${DISTRIB_RELEASE}"
  elif [[ -f /etc/debian_version ]]; then
    # Older Debian/Ubuntu/etc.
    OS=Debian
    VER="$(cat /etc/debian_version)"
  elif [[ -f /etc/SuSe-release ]]; then
    # Older SuSE/etc.
    ...
  elif [[ -f /etc/redhat-release ]]; then
    # Older Red Hat, CentOS, etc.
    ...
  else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS="$(uname -s)"
    VER="$(uname -r)"
  fi
}

function yesno() {
  local ans
  local ok=0
  local default
  local t
  if [[ "${UNIT_TEST}" == "1" ]]; then
    local timeout="1"
  else
    local timeout="0"
  fi

  while [[ "${1}" ]]
  do
    case "${1}" in

    --default)
      shift
      default="${1}"
      if [[ ! "${default}" ]]; then error "Missing default value"; fi
      t=$(tr '[:upper:]' '[:lower:]' <<< "${default}")

      if [[ "${t}" != 'y'  &&  "${t}" != 'yes'  &&  "${t}" != 'n'  &&  "${t}" != 'no' ]]; then
        error "Illegal default answer: ${default}"
      fi
      default="${t}"
      shift
      ;;

    --timeout)
      shift
      timeout="${1}"
      if [[ ! "${timeout}" ]]; then error "Missing timeout value"; fi
      if [[ ! "${timeout}" =~ ^[0-9][0-9]*$ ]]; then error "Illegal timeout value: ${timeout}"; fi
      shift
      ;;

    -*)
      error "Unrecognized option: ${1}"
      ;;

    *)
      break
      ;;
    esac
  done

  if [[ "${timeout}" -ne "0"  &&  ! "${default}" ]]; then
    error "Non-zero timeout requires a default answer"
  fi

  if [[ ! "${*}" ]]; then error "Missing question"; fi

  while [[ "${ok}" -eq "0" ]]
  do
    if [[ "${timeout}" -ne "0" ]]; then
      if ! read -rt "${timeout}" -p "$*" ans; then
        ans="${default}"
      else
        # Reset timeout if answer entered.
        timeout="0"
        if [[ ! "${ans}" ]]; then ans="${default}"; fi
      fi
    else
      read -rp "$*" ans
      if [[ ! "${ans}" ]]; then
        ans="${default}"
      else
        ans=$(tr '[:upper:]' '[:lower:]' <<< "${ans}")
      fi 
    fi

    if [[ "${ans}" == 'y'  ||  "${ans}" == 'yes'  ||  "${ans}" == 'n'  ||  "${ans}" == 'no' ]]; then
      ok="1"
    fi

    if [[ "${ok}" -eq "0" ]]; then warning "Valid answers are: yes, y, no, n"; fi
  done
  [[ "${ans}" = "y" || "${ans}" == "yes" ]]
}

function install_git() {
  # Git
  echo -e "\nConfiguring git"
  read -rp "Full name: " git_name
  read -rp "Email address: " git_email
  if [[ -z "${git_name}" ]] || [[ -z "${git_email}" ]]; then
    echo "Skipping git configuration"
  else
    git config --global user.name "${git_name}"
    git config --global user.email "${git_email}"
  fi
}

function install_mariadb() {
  if yesno --default yes "Continue? [Y/n] "; then
    sudo apt-get update
    sudo apt-get install mariadb-server
    sudo service mysql start
    sudo service mysql status
    status=$?
    if [[ "${status}" == "0" ]]; then
      sudo mysql_secure_installation
      sudo service mysql stop
    fi
  fi
}

function install_php() {
  if yesno --default yes "Continue? [Y/n] "; then
    sudo apt-get install lsb-release ca-certificates apt-transport-https software-properties-common -y
    sudo add-apt-repository ppa:ondrej/php 
    sudo add-apt-repository ppa:ondrej/apache2
    sudo apt-get update
    sudo apt-get install php8.1 -y
    sudo apt-get install -y php8.1-cli php8.1-common php8.1-mysql php8.1-zip php8.1-gd php8.1-mbstring php8.1-curl php8.1-xml php8.1-bcmath libapache2-mod-php php-mysql php-pear -y
    php -v
  fi
}

function install_composer() {
  if yesno --default yes "Continue? [Y/n] "; then
    curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
    HASH=`curl -sS https://composer.github.io/installer.sig`
    php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
    sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
  fi
}

function install_wpcli() {
  if [[ ! -x "$(command -v wp)" ]]; then
    echo ""
    if yesno --default yes "Install wp-cli? [Y/n] "; then
      wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
      sudo chmod u+x wp-cli.phar
      sudo mv wp-cli.phar /usr/local/bin/wp
      wp --info
    fi
  fi
}

function install_webmin() {
  if yesno --default yes "Continue? [Y/n] "; then
    curl -fsSL https://download.webmin.com/jcameron-key.asc | sudo gpg --dearmor -o /usr/share/keyrings/webmin.gpg
    sudo echo 'deb [signed-by=/usr/share/keyrings/webmin.gpg] http://download.webmin.com/download/repository sarge contrib' >> /etc/apt/sources.list
    sudo apt update
    sudo apt install webmin -y
  fi
}

function install_sshkey() {
  echo ""
  if yesno --default yes "Generate ssh key? [Y/n] "; then
    ssh-keygen -t rsa -b 4096
    echo ""
    tail ~/.ssh/id_rsa.pub
    echo -e "\nAdd the key above at the following URLs:"
    echo "https://github.com/settings/keys"
    echo "https://bitbucket.org/account/settings/ssh-keys/"
  fi
}

# Begin app
check_os
if [[ -n "${OS}" ]] && [[ -n "${VER}" ]]; then
  echo -e "\nSetting up ${OS} ${VER}"
else
  # No values, crash out for now
  echo -e "\nUnkown OS version"
  exit 1
fi

# Get started, install the basics
if yesno --default yes "Continue? [Y/n] "; then
  sudo apt-get update
  sudo apt-get upgrade -y
  sudo apt-get install build-essential gcc g++ make nodejs git npm apache2 x11-apps -y
else
  exit
fi

# Git, required so no y/n
install_git

# MariaDB
echo -e "\nInstalling MariaDB"; install_mariadb

# PHP 8.1
echo -e "\nInstalling PHP 8.1"; install_php

# Composer 2
echo -e "\nInstalling Composer 2.x"; install_composer

# wp-cli
install_wpcli

# Webmin
echo -e "\nInstalling Webmin"; install_webmin

# Install ssh key
install_sshkey

# Clean up
echo -e "\nCleaning up..."
echo "[automount]" >> /tmp/wsl.conf
echo "options = \"metadata\"" >> /tmp/wsl.conf

#Exit
echo -e "\nReboot your computer or run 'wsl -t ${OS}' from your Windows CMD shell."
exit 0
