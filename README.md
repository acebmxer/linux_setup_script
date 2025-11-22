# linux_install_script
Script to run after fresh linux install

This scrtip sets the timezone to Est, install dotfile, and XCP-NG tools. It also install topgrade to fully update the system.

# With out Docker
wget https://raw.githubusercontent.com/acebmxer/linux_install_script/main/setup.sh && chmod +x setup.sh && bash setup.sh

# With Docker
wget https://raw.githubusercontent.com/acebmxer/linux_install_script/main/setup_with_docker.sh && chmod +x setup.sh && bash setup.sh
