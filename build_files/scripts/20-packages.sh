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
## 2b. XPADNEO: usa il pacchetto headers matching del kernel reale
## ==========================================
# In questo ambiente il kernel di base / reale del repo non è sempre identico al
# nome del pacchetto devel. Per il supporto DKMS/akmods bisogna usare il package
# headers che matcha il kernel in uso, non costruire un nome a mano.
#
# Esempio corretto:
#   kernel-devel-matched
#
# Il nome del package devel non sempre coincide con la stringa del kernel custom
# usata nell'immagine (es. rakuos, v3, ecc.), quindi il pacchetto va cercato come
# metapacchetto "matched" che risolve automaticamente la versione giusta.
KERNEL_IMAGE_VERSION="${KERNEL_IMAGE_VERSION:-$(uname -r 2>/dev/null || echo 'unknown')}"
KERNEL_DEVEL_PKG="${KERNEL_DEVEL_PKG:-kernel-devel-matched}"

# Risolviamo la versione effettiva del package headers matching per il kernel del repo.
KERNEL_DEVEL_VERSION="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}' "${KERNEL_DEVEL_PKG}" 2>/dev/null || true)"

if [[ -z "${KERNEL_DEVEL_VERSION}" ]]; then
    echo "FATAL: ${KERNEL_DEVEL_PKG} non è disponibile nel repo di RakuOS o non è un package headers matching valido."
    exit 1
fi

if ! rpm -q "${KERNEL_DEVEL_PKG}" >/dev/null 2>&1; then
    echo "FATAL: ${KERNEL_DEVEL_PKG} non è disponibile nel repo di RakuOS."
    echo "Per questa pipeline il pacchetto headers deve essere quello che matcha il kernel attivo."
    exit 1
fi

echo "Kernel immagine: ${KERNEL_IMAGE_VERSION}"
echo "Kernel-devel del repo: ${KERNEL_DEVEL_PKG} (${KERNEL_DEVEL_VERSION})"

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
