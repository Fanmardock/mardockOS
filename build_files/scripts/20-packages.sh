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
    ddcutil \
    adw-gtk3-theme \
    qt6ct \
    libnotify \
    power-profiles-daemon \
    libva-utils \
    clinfo \
    vulkan-tools

## ==========================================
## 2b. XPADNEO: compila contro il kernel esatto dell'immagine
## ==========================================
# Non usare un kernel diverso da quello in esecuzione: questo è il punto critico.
# Se il kernel-devel non coincide, il modulo viene compilato contro i headers sbagliati
# e poi non carica mai correttamente.
CURRENT_KERNEL="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null || uname -r)"
TARGET_KERNEL="${CURRENT_KERNEL}"

echo "Kernel dell'immagine: ${TARGET_KERNEL}"

# In Fedora/RakuOS l'installazione corretta è via akmod + kernel-devel compatibile.
# Se non c'è il devel per il kernel corrente, non fare un fallback random a una versione diversa.
if ! rpm -q "kernel-devel-${TARGET_KERNEL}" >/dev/null 2>&1; then
    echo "FATAL: kernel-devel-${TARGET_KERNEL} non disponibile nei repo configurati."
    echo "Installa prima il kernel-devel corretto per il kernel attivo, poi riprova."
    echo "Comando tipico: rum install -y kernel-devel-$(uname -r)"
    exit 1
fi

rum install -y \
    dkms \
    gcc \
    make \
    git \
    "kernel-devel-${TARGET_KERNEL}" \
    akmod-xpadneo

# Costruisce il modulo proprio per il kernel attivo. Non forzare versioni alternative.
akmods --force --rebuild --kernels "${TARGET_KERNEL}"

# Verifica il modulo effettivamente costruito.
if ! find "/lib/modules/${TARGET_KERNEL}" -type f \( -iname '*xpadneo*.ko*' -o -iname '*xpad*.ko*' \) | grep -q .; then
    echo "ERROR: nessun modulo xpadneo costruito in /lib/modules/${TARGET_KERNEL}."
    exit 1
fi

mkdir -p /etc/modules-load.d/
printf '%s\n' "hid-xpadneo" > /etc/modules-load.d/xpadneo.conf

# Smoke test: se il modulo esiste nel kernel corretto, lo carica in memoria.
modprobe xpadneo || {
    echo "WARNING: modprobe xpadneo fallito in build phase; il pacchetto è stato comunque costruito."
}

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
## 5. PULIZIA PACCHETTI IN ECESSO
## ==========================================
rum remove -y waybar swaylock alacritty cosmic-comp cosmic-initial-setup cosmic-settings || true
