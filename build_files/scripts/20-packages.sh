#!/bin/bash
set -euo pipefail

## ==========================================
## 1. RIMOZIONE PREVENTIVA CONFLITTI
## ==========================================
rum remove -y tuned-ppd || true

## ==========================================
## 2. STACK RAKUOS / NIRI / COMPONENTI DI SISTEMA
## ==========================================
rum install -y \
    niri \
    xwayland-satellite \
    dms \
    dms-greeter \
    dankcalendar-git \
    danksearch \
    quickshell \
    dux-qt-base \
    greetd \
    cups-pk-helper \
    xdg-desktop-portal \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk \
    xdg-user-dirs-gtk \
    wl-clipboard \
    wtype \
    wl-mirror \
    gnome-keyring \
    gnome-keyring-pam \
    fprintd-pam \
    pipewire \
    wireplumber \
    pavucontrol \
    blueman \
    zenity \
    ddcutil \
    adw-gtk3-theme \
    qt6ct \
    libnotify \
    power-profiles-daemon \
    libva-utils \
    clinfo \
    vulkan-tools

## ==========================================
## 2b. XPADNEO: modulo firmato RakuOS
## ==========================================
# RakuOS non compila i driver out-of-tree dentro l'immagine: i moduli sono
# costruiti e firmati da RakuOS e pubblicati come pacchetti rakuos-kmod-*.
# rum installa automaticamente il build corretto per il kernel dell'immagine
# (label org.rakuos.kernel.release), quindi:
#   - non usare uname -r: è il kernel del runner, non quello dell'immagine
#   - non installare kernel-devel, akmods, dkms, gcc o make
#   - non ricavare la versione del kernel dal nome di un pacchetto devel
#   - non lanciare akmods --force --rebuild --kernels ...
#
# xpadneo richiede il repo Terra (il suo pacchetto fornisce
# xpadneo-kmod-common). terra-release è nell'immagine base, ma il repo è
# disabilitato di default.

if ! rum repolist --all 2>/dev/null | awk '$1 == "terra" { found = 1 } END { exit !found }'; then
    echo "FATAL: repo Terra assente dall'immagine base: impossibile installare rakuos-kmod-xpadneo."
    rum repolist --all 2>/dev/null || true
    exit 1
fi

rum config-manager --set-enabled terra

# Fail-fast: senza il modulo firmato l'immagine non è completa.
# Nessun controllo "find /lib/modules/..." e nessun modprobe: in fase di build
# agirebbero sul kernel del runner, non su quello dell'immagine.
rum install -y rakuos-kmod-xpadneo

mkdir -p /etc/modules-load.d/
printf '%s\n' 'hid-xpadneo' > /etc/modules-load.d/xpadneo.conf

## ==========================================
## 3. APPLICAZIONI, UTILITY & XBOX DRIVERS
## ==========================================
rum install -y --skip-broken --skip-unavailable \
    code \
    libvirt virt-manager qemu-kvm flatpak-builder wlr-randr \
    iotop sysstat lxqt-openssh-askpass lxpolkit parallel \
    rakuos-software-gtk \
    bluez \
    bluez-tools \
    nautilus \
    kitty \
    ghostty \
    mpv \
    rfkill \
    gvfs \
    gvfs-mtp \
    gvfs-nfs \
    file-roller \
    gnome-calculator \
    gnome-disk-utility \
    nautilus-open-any-terminal

## ==========================================
## 4. FIX CONTROLLER XBOX (BLUETOOTH ERTM)
## ==========================================
mkdir -p /etc/modprobe.d/
echo "options bluetooth disable_ertm=1" > /etc/modprobe.d/bluetooth-xbox.conf
echo "options usbcore autosuspend=-1" | tee /etc/modprobe.d/disable-autosuspend.conf

## ==========================================
## 5. PULIZIA PACCHETTI IN ECCESSO
## ==========================================
rum remove -y waybar swaylock alacritty cosmic-comp cosmic-initial-setup cosmic-settings || true
