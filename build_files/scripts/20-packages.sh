#!/bin/bash
set -ouex pipefail

## ==========================================
## 1. RIMOZIONE PREVENTIVA CONFLITTI
## ==========================================
# Rimozione di tuned-ppd per consentire l'installazione di power-profiles-daemon
# Rimozione di qt6ct nativo se presente, per evitare conflitti
rum remove -y tuned-ppd || true

## ==========================================
## 2. STACK RAKUOS / NIRI / COMPONENTI DI SISTEMA
## ==========================================
rum install -y --allowerasing \
    niri \
    xwayland-satellite \
    dms \
    dms-greeter \
    dankcalendar-git \
    danksearch \
    quickshell \
    greetd \
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
    ddcutil \
    adw-gtk3-theme \
    qt6ct \
    libnotify \
    power-profiles-daemon \
    libva-utils \
    clinfo \
    vulkan-tools

## ==========================================
## 3. APPLICAZIONI, UTILITY & XBOX DRIVERS
## ==========================================
rum install -y --allowerasing \
    code \
    libvirt virt-manager qemu-kvm flatpak-builder wlr-randr \
    iotop sysstat lxqt-openssh-askpass lxpolkit parallel \
    rakuos-software-gtk \
    akmod-xpadneo \
    bluez \
    bluez-tools \
    nautilus \
    kitty \
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
## 3b. BUILD XPADNEO AKMOD SUL KERNEL DELL'IMMAGINE
## ==========================================
# In container `uname -r` restituisce il kernel dell'HOST (es. runner GitHub),
# quindi l'akmod finisce in /lib/modules/<ver-host> e al boot non viene mai caricato.
# Costruiamo esplicitamente contro il kernel spedito dall'immagine, fail-fast se manca.
IMAGE_KERNEL="$(basename "$(ls -d /lib/modules/*/ | head -n1)")"
echo "Building xpadneo against image kernel: ${IMAGE_KERNEL}"
rum install -y "kernel-devel-${IMAGE_KERNEL}" || rum install -y kernel-devel
akmods --force --rebuild --kernels "${IMAGE_KERNEL}"
find "/lib/modules/${IMAGE_KERNEL}" -name 'xpad.ko*' | grep -q . || \
    { echo "ERROR: xpad.ko non trovato sotto /lib/modules/${IMAGE_KERNEL}"; exit 1; }

# Caricamento automatico del modulo all'avvio (systemd-modules-load)
mkdir -p /etc/modules-load.d/
echo "hid-xpadneo" > /etc/modules-load.d/xpadneo.conf

## ==========================================
## 4. FIX CONTROLLER XBOX (BLUETOOTH ERTM)
## ==========================================
# Disabilita ERTM per evitare disconnessioni del pad Xbox via Bluetooth
mkdir -p /etc/modprobe.d/
echo "options bluetooth disable_ertm=1" > /etc/modprobe.d/bluetooth-xbox.conf

echo "options usbcore autosuspend=-1" | tee /etc/modprobe.d/disable-autosuspend.conf
## ==========================================
## 5. PULIZIA PACCHETTI IN ECESSO (POST-INSTALL)
## ==========================================
rum remove -y waybar swaylock alacritty cosmic-comp cosmic-initial-setup cosmic-settings || true
