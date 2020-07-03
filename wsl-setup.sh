  
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

# Begin app
check_os
if [[ -n "${OS}" ]] && [[ -n "${VER}" ]]; then
  echo -e "\nSetting up ${OS} ${VER}"
else
  # No values, crash out for now
  exit 1
fi

# Get started
if yesno --default yes "Continue? [Y/n] "; then
  sudo apt update
  sudo apt upgrade -y
  sudo apt-get install build-essential gcc g++ make nodejs git composer npm
else
  exit
fi

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

# Mysql
echo -e "\nInstalling Mysql"
if yesno --default yes "Continue? [Y/n] "; then
  RUNLEVEL=1

  # Ugly workaround for /etc/profile.d/wsl-integration.sh, see
  # https://github.com/wslutilities/wslu/issues/101
  sudo mkdir //.cache

  sudo apt install mysql-server

  # Correct the HOME issue
  sudo usermod -d /var/lib/mysql/ mysql

  sudo service mysql start
  sudo service mysql status
  status=$?
  if [[ "${status}" == "0" ]]; then
    sudo mysql_secure_installation
    sudo service mysql stop
  fi
  sudo rm -rf //.cache
fi

# wp-cli
if [[ ! -x "$(command -v wp)" ]]; then
  echo ""
  if yesno --default yes "Install wp-cli? [Y/n] "; then
    wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    sudo chmod u+x wp-cli.phar
    sudo mv wp-cli.phar /usr/local/bin/wp
    wp --info
  fi
fi

# Fix weird write issue with git vs. wsl
echo ""
if yesno --default yes "Applying filesystem fix? [Y/n] "; then
  echo "[automount]" >> /tmp/wsl.conf
  echo "options = \"metadata\"" >> /tmp/wsl.conf
  sudo mv /tmp/wsl.conf /etc/wsl.conf
fi

echo ""
if yesno --default yes "Generate ssh key? [Y/n] "; then
  ssh-keygen -t rsa -b 4096
  echo ""
  tail ~/.ssh/id_rsa.pub
  echo -e "\nAdd the key above at the following URLs:"
  echo "https://github.com/settings/keys"
  echo "https://bitbucket.org/account/settings/ssh-keys/"
fi

# Fix for weird sleep issue
if [[ "${OS}" == "Ubuntu" ]] && [[ "${VER}" == "20.04" ]]; then
  echo -e "\n${OS} ${VER} has a bug in its implementation of the 'sleep' command."
  echo "The fix involves downgrading a few libraries."
  if yesno --default yes "Apply fix? [Y/n] "; then
    wget https://launchpad.net/~rafaeldtinoco/+archive/ubuntu/lp1871129/+files/libc6_2.31-0ubuntu8+lp1871129~1_amd64.deb
    sudo dpkg --install libc6_2.31-0ubuntu8+lp1871129~1_amd64.deb
    sudo apt-mark hold libc6
    sudo apt --fix-broken install
    sudo apt full-upgrade
  fi
fi

echo -e "\nReboot your computer or run 'wsl -t ${OS}' from your Windows CMD shell."
