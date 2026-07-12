#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

# Install packages

## No Docker - for now
# rpm --import https://download.docker.com/linux/fedora/gpg
# dnf5 config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo

# dnf5 install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# groupadd -r docker

## VsCode from Microsoft
rpm --import https://packages.microsoft.com/keys/microsoft.asc

cat << 'EOF' > /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

dnf5 install -y code

## Terra Software (Zed editor)
dnf5 config-manager setopt terra.enabled=1
dnf5 config-manager setopt terra-mesa.enabled=1
dnf5 install -y zed
dnf5 config-manager setopt terra.enabled=0
dnf5 config-manager setopt terra-mesa.enabled=0
rm -f /etc/yum.repos.d/terra*.repo

## Alacritty
dnf5 install -y alacritty

# Remove Software

dnf5 remove -y waydroid

#### Example for enabling a System Unit File

systemctl enable podman.socket
