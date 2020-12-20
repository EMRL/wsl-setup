# WSL Setup
New and improved for WSL 2

## First steps
This is just how we initially setup a WSL environment on our Windows wordkstations. There are probably better ways to do it.

### Enable WSL
- Open PowerShell tool as an Administrator 
- ` dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart`
- Enable Virtual Machine Platform
` dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all`
- Reboot

### Get ready
- Open PowerShell tool as an Administrator 
- Set WSL2 as default
- `wsl --set-default-version 2`
- Update Kernel
- Install from https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi
- Install a distro
- Ubuntu 20.04 LTS https://www.microsoft.com/en-gb/p/ubuntu-2004-lts/9n6svws3rx71
- Create user/password

### Install support apps
- Install Hyper from https://releases.hyper.is/download/win
- Edit default Hyper shell preference
- Value should be `shell: 'C:\\Windows\\System32\\bash.exe',`
- Install VS Code from https://code.visualstudio.com/Download

### Install and setup minimum development bits
- Run script at https://github.com/EMRL/wsl-setup
