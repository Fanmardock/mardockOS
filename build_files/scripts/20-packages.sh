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
## 2b. XPADNEO: usa il kernel-devel reale del repo per l'immagine RakuOS
## ==========================================
# Il kernel dell'immagine RakuOS usa la nomenclatura del repo:
#   7.2.6-rakuos.3.v3.fc44.x86_64
# Il pacchetto devel corrispondente nel repo ha lo stesso suffisso, non il
# nome stock Fedora: kernel-devel-7.2.6-rakuos.3.v3.fc44.x86_64
# Quindi non usare uname -r o il nome dell'immagine per costruire il pacchetto devel.
KERNEL_IMAGE_VERSION="${KERNEL_IMAGE_VERSION:-7.2.6-rakuos.3.v3.fc44.x86_64}"
KERNEL_DEVEL_VERSION="${KERNEL_DEVEL_VERSION:-7.2.6-rakuos.3.v3.fc44.x86_64}"
KERNEL_DEVEL_PKG="kernel-devel-${KERNEL_DEVEL_VERSION}"

echo "Kernel immagine: ${KERNEL_IMAGE_VERSION}"
echo "Kernel-devel del repo: ${KERNEL_DEVEL_PKG}"

if ! rpm -q "${KERNEL_DEVEL_PKG}" >/dev/null 2>&1; then
    echo "FATAL: ${KERNEL_DEVEL_PKG} non è disponibile nel repo di RakuOS."
    echo "Per questa pipeline il devel deve essere presente esattamente in questa versione."
    exit 1
fi

rum install -y \
    dkms \
    gcc \
    make \
    git \
    "${KERNEL_DEVEL_PKG}" \
    akmod-xpadneo

# Costruzione del modulo contro il kernel-devel reale supportato dal repo.
akmods --force --rebuild --kernels "${KERNEL_DEVEL_VERSION}"

# Verifica modulo generato per il kernel reale del repo.
if ! find "/lib/modules/${KERNEL_DEVEL_VERSION}" -type f \( -iname '*xpadneo*.ko*' -o -iname '*xpad*.ko*' \) | grep -q .; then
    echo "ERROR: nessun modulo xpadneo costruito in /lib/modules/${KERNEL_DEVEL_VERSION}."
    exit 1
fi

mkdir -p /etc/modules-load.d/
printf '%s\n' "hid-xpadneo" > /etc/modules-load.d/xpadneo.conf

modprobe xpadneo || {
    echo "WARNING: modprobe xpadneo fallito in questa fase; il modulo è stato comunque costruito per il kernel corretto del repo."
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
