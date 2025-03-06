#!/bin/bash

is_ubuntu=`awk -F '=' '/PRETTY_NAME/ { print $2 }' /etc/os-release | egrep Ubuntu -i`
is_centos=`awk -F '=' '/PRETTY_NAME/ { print $2 }' /etc/os-release | egrep Rocky -i`

# Function to install basic tools on Ubuntu
function ubuntu_basic_install() {
    sudo apt -y update
    sudo apt -y install git wget net-tools epel-release htop vim nano nmon telnet rsync sysstat lsof nfs-common cifs-utils chrony resolvconf
	sudo "nameserver 8.8.8.8" > /etc/resolvconf/resolv.conf.d/head
	sudo resolvconf --enable-updates
	sudo resolvconf -u	
	sudo systemctl restart resolvconf && systemctl enable resolvconf
    sudo timedatectl set-timezone Asia/Ho_Chi_Minh
    sudo ufw disable 
    sudo systemctl start chronyd
    sudo systemctl restart chronyd
    sudo chronyc sources
    sudo timedatectl set-local-rtc 0
}

# Function to install basic tools on CentOS
function centos_basic_install() {
    sudo yum install -y epel-release
    sudo timedatectl set-timezone Asia/Ho_Chi_Minh
    sudo yum install -y git wget net-tools epel-release htop vim nano nmon telnet rsync sysstat lsof nfs-utils cifs-utils chrony resolvconf
	sudo echo "nameserver 8.8.8.8" > /etc/resolvconf/resolv.conf.d/head
	sudo resolvconf --enable-updates
	sudo resolvconf -u	
	sudo systemctl restart resolvconf && systemctl enable resolvconf
    sudo systemctl stop firewalld
    sudo systemctl disable firewalld
    sudo systemctl mask --now firewalld
    sudo systemctl enable chronyd
    sudo systemctl restart chronyd
    sudo chronyc sources
    sudo timedatectl set-local-rtc 0
}

# Function to enable limiting resources
function enable_limiting_resources() {
    echo "Enable limiting resources"
    
    sudo sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

    echo 'GRUB_CMDLINE_LINUX="cdgroup_enable=memory swapaccount=1"' | sudo tee -a /etc/default/grub
    sudo update-grub
}
# Function to set file limits
function set_file_limits() {
    echo "Setting file limits"
    
    # Set sysctl parameters
    echo "fs.file-max=100000" | sudo tee -a /etc/sysctl.conf
    echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
    
    # Set limits for users
    echo "* soft nofile 100000" | sudo tee -a /etc/security/limits.conf
    echo "* hard nofile 100000" | sudo tee -a /etc/security/limits.conf
}

# Function to configure bash aliases and functions
function configure_bash_aliases() {
	echo "alias dils='docker image ls'
	alias dirm='docker image rm'
	
	alias dcls='docker container ls -a --size'
	alias dcrm='docker container rm'
	
	alias dcb='docker build . -t'
	
	alias dr='docker restart'
	
	alias dl='docker logs'
	
	alias ds='docker stats'
	
	alias din='docker inspect'
	
	alias dcc='docker cp'
	
	alias dload='docker load -i'
	
	alias dlf='docker logs -f --tail 100'

    function dcl() {
        sudo truncate -s 0 \$(docker inspect --format='{{.LogPath}}' \$1)
    }
    
    function drun() {
        docker run --rm \$3 --name \$2 -it \$1 /bin/bash
    }
    
    function drun_network_host() {
        docker run --rm --network=host \$3 --name \$2 -it \$1 /bin/bash
    }
    
    function dsave() {
        docker save -o \$2 \$1
    }
    
    function dexec() {
        container=\$1
        docker exec -it \$container /bin/bash
    }
    
    function dt() {
        for i in \$(docker container ls --format "{{.Names}}"); do
            echo Container: \$i
            docker top \$i -eo pid,ppid,cmd,uid
        done
    }" | sudo tee -a /home/isofh/.bashrc
}

# Function to install Docker on Ubuntu
function ubuntu_docker_install() {
    sudo apt-get -y update
    sudo apt-get remove -y docker docker-engine docker.io containerd runc
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common git vim 
	
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
	echo \
		"deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
		$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get -y update
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io

    sudo bash -c 'touch /etc/docker/daemon.json' && sudo bash -c "echo -e '{\n\t\"bip\": \"55.55.1.1/24\"\n}' > /etc/docker/daemon.json"

    sudo systemctl enable docker.service
    sudo systemctl start docker
    sudo usermod -aG docker isofh

    echo "Docker has been installed successfully."
}

# Function to install Docker on CentOS
function centos_docker_install() {
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2 git vim
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum -y install docker-ce docker-ce-cli containerd.io

    sudo bash -c 'touch /etc/docker/daemon.json' && sudo bash -c "echo -e '{\n\t\"bip\": \"55.55.1.1/24\"\n}' > /etc/docker/daemon.json"

	sudo systemctl enable docker.service
	sudo systemctl start docker
	sudo usermod -aG docker isofh
	echo "Docker has been installed successfully."		
}

# Function to install Docker Compose
function docker_compose_install() {
    COMPOSE_VERSION=$(git ls-remote https://github.com/docker/compose | grep refs/tags | grep -oE "[0-9]+\.[0-9][0-9]+\.[0-9]+$" | sort --version-sort | tail -n 1)
    sudo sh -c "curl -L https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m) > /usr/local/bin/docker-compose"
    sudo chmod +x /usr/local/bin/docker-compose
    sudo sh -c "curl -L https://raw.githubusercontent.com/docker/compose/${COMPOSE_VERSION}/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose"
    docker-compose --version
    echo "Docker-compose has been installed successfully."
}

# Function to install Docker
function docker_install() {
	if [ ! -z "$is_ubuntu" ]; then
		ubuntu_docker_install
	elif [ ! -z "$is_centos" ]; then
		centos_docker_install
	fi
}

# Function to reboot the server
function reboot_server() {
	read -p "Please reboot for apply all config. [y/n]: " -n 1 -r
	echo    
	if [[ $REPLY =~ ^[Yy]$ ]]; then
	    /sbin/reboot
	fi
}

############################################################

echo "Run with root privileges"

read -p "Do you want to add aliases for user isofh? (y/n): " addAliases
if [ "$addAliases" == "y" ]; then
    # Add aliases for the user 'isofh'
    configure_bash_aliases
    echo "Aliases added for user isofh."
else
    echo "Skipping alias setup for user isofh."
fi

###--------
# Linux - Basic tools
echo "Installing basic tools for Linux"
if [ ! -z "$is_ubuntu" ]; then
	ubuntu_basic_install
elif [ ! -z "$is_centos" ]; then
	centos_basic_install
fi

# Enable limiting resources
enable_limiting_resources

# Set file limits
set_file_limits

# Install node_exporter
install_node_exporter

echo "Script execution completed."

