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
## 2b. XPADNEO: installa/compila solo sul kernel compatibile
## ==========================================

# Usa il kernel reale dell'immagine, non /lib/modules/*/ (può essere quello dell'host/container)
CURRENT_KERNEL="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null || uname -r)"
echo "Kernel corrente dell'immagine: ${CURRENT_KERNEL}"

TARGET_KERNEL="${CURRENT_KERNEL}"

# Se il kernel corrente non ha il devel, scegli dinamicamente una versione disponibile compatibile
if ! rpm -q "kernel-devel-${TARGET_KERNEL}" >/dev/null 2>&1; then
    echo "kernel-devel per ${TARGET_KERNEL} non disponibile; cerco una versione compatibile precedente..."

    COMPATIBLE_KERNEL="$(repoquery --available --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-devel 2>/dev/null | sort -V | tail -n 1 || true)"

    if [ -z "${COMPATIBLE_KERNEL}" ]; then
        echo "FATAL: nessun kernel-devel disponibile in repo. xpadneo non può essere costruito per questo kernel."
        exit 1
    fi

    TARGET_KERNEL="${COMPATIBLE_KERNEL}"
    echo "Kernel compatibile scelto: ${TARGET_KERNEL}"

    # Se vuoi pinare la versione scelta, bloccalo così non scappi oltre
    rum install -y "kernel-${TARGET_KERNEL}" "kernel-devel-${TARGET_KERNEL}" || true
    rum versionlock add kernel kernel-devel || true
else
    echo "Kernel corrente compatibile con xpadneo: ${TARGET_KERNEL}"
    rum install -y "kernel-devel-${TARGET_KERNEL}"
fi

echo "Building xpadneo against image kernel: ${TARGET_KERNEL}"
akmods --force --rebuild --kernels "${TARGET_KERNEL}"

find "/lib/modules/${TARGET_KERNEL}" -name 'xpad.ko*' | grep -q . || \
    { echo "ERROR: xpad.ko non trovato sotto /lib/modules/${TARGET_KERNEL}"; exit 1; }

mkdir -p /etc/modules-load.d/
echo "hid-xpadneo" > /etc/modules-load.d/xpadneo.conf

## ==========================================
## 3. APPLICAZIONI, UTILITY & XBOX DRIVERS
## ==========================================
rum install -y --skip-broken --skip-unavailable \
    code \
    libvirt virt-manager qemu-kvm flatpak-builder wlr-randr \
    iotop sysstat lxqt-openssh-askpass lxpolkit parallel \
    rakuos-software-gtk \
    akmod-xpadneo \
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
