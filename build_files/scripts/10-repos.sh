#!/bin/bash
set -ouex pipefail

FEDORA_VERSION=$(rpm -E %fedora)

rum install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm \
               https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm

rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo

# DMS 2.1 dei vecchi repo AvengeMedia usa /usr/bin/qs (Quickshell 0.3.2) e non
# riconosce il pragma DiskCache. Il runtime Dux 2.2 carica libdux-qt-base
# direttamente nel processo dms: serve il canale duxlabs/dms-git, che a sua
# volta dipende da duxlabs/dux-repo per dux-qt-base-git.
# Rimuove anche l'eventuale repo legacy ereditato da un'immagine precedente.
rm -f /etc/yum.repos.d/avengemedia-dms-fedora-*.repo

curl --output-dir "/etc/yum.repos.d/" \
  --remote-name "https://copr.fedorainfracloud.org/coprs/duxlabs/dux-repo/repo/fedora-${FEDORA_VERSION}/duxlabs-dux-repo-fedora-${FEDORA_VERSION}.repo" \
  --remote-name "https://copr.fedorainfracloud.org/coprs/duxlabs/dms-git/repo/fedora-${FEDORA_VERSION}/duxlabs-dms-git-fedora-${FEDORA_VERSION}.repo"

curl -Lo /etc/yum.repos.d/nautilus-open-any-terminal.repo \
  https://copr.fedorainfracloud.org/coprs/monkeygold/nautilus-open-any-terminal/repo/fedora-${FEDORA_VERSION}/monkeygold-nautilus-open-any-terminal-fedora-${FEDORA_VERSION}.repo