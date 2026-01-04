# linux_setup_script
Script to run after fresh linux install

This scrtip sets the timezone to Est, install dotfile, and XCP-NG tools. It also install topgrade to fully update the system.

### Clone the repo and run setup.sh
```
git clone "https://github.com/acebmxer/linux_setup_script.git"
cd linux_setup_script && chmod +x * && bash setup.sh
```
### Log file can be found in /var/log/linux_setup_script.log

### Force a light theme (works even if the terminal is dark
SETUP_THEME=light ./setup.sh

### Force a dark theme
SETUP_THEME=dark ./setup.sh

Each script file can be ran seuperalty if you wanted to.
