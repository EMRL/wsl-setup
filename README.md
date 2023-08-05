# WSL Setup
New and improved for WSL 2

## First steps
This is just how we initially setup a WSL environment on our Windows workstations. There are probably better ways to do it.

### Enable WSL
- Open PowerShell tool as an Administrator 
- Enable WSL and install distro by using the command `wsl --install`
- Reboot computer
- Launch Ubuntu shell
- Create user/password

### Install support apps
- Install VS Code from https://code.visualstudio.com/Download

### Install and setup minimum development bits
- Run script at https://github.com/EMRL/wsl-setup

### Post-script notes
For some weird reason, root password was not working when trying to run `mysql -u root -p` - after trying many different solutions that all failed, I resorted to using Webmin (which accepted root password fine) to re-saved the root password and everything works fine now. Weird shit.
