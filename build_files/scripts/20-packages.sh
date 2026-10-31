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
## 2b. XPADNEO: installa il modulo per il kernel attivo esatto
## ==========================================
# Per RakuOS il kernel in esecuzione e il kernel-devel sono già in una forma custom
# del tipo: 7.2.6-rakuos.3.v3.fc44.x86_64
# La pipeline deve usare questa versione esatta, non un valore calcolato dal sistema.
KERNEL_VERSION="${KERNEL_VERSION:-7.2.6-rakuos.3.v3.fc44.x86_64}"
KERNEL_DEVEL_PKG="kernel-devel-${KERNEL_VERSION}"

echo "Kernel attivo da usare: ${KERNEL_VERSION}"
echo "Kernel-devel richiesto: ${KERNEL_DEVEL_PKG}"

if ! rpm -q "${KERNEL_DEVEL_PKG}" >/dev/null 2>&1; then
    echo "FATAL: ${KERNEL_DEVEL_PKG} non è disponibile nel repo di RakuOS."
    echo "Questa build è stata pinata alla versione esatta del kernel RakuOS attivo e non può usare un kernel diverso."
    exit 1
fi

rum install -y \
    dkms \
    gcc \
    make \
    git \
    "${KERNEL_DEVEL_PKG}" \
    akmod-xpadneo

# Costruzione del modulo esattamente per il kernel attivo in uso.
akmods --force --rebuild --kernels "${KERNEL_VERSION}"

# Verifica modulo generato per questo kernel esatto.
if ! find "/lib/modules/${KERNEL_VERSION}" -type f \( -iname '*xpadneo*.ko*' -o -iname '*xpad*.ko*' \) | grep -q .; then
    echo "ERROR: nessun modulo xpadneo costruito in /lib/modules/${KERNEL_VERSION}."
    exit 1
fi

mkdir -p /etc/modules-load.d/
printf '%s\n' "hid-xpadneo" > /etc/modules-load.d/xpadneo.conf

# Prova il caricamento del modulo se l'initramfs/loader del build lo permette.
modprobe xpadneo || {
    echo "WARNING: modprobe xpadneo fallito in questa fase; il modulo è stato comunque costruito per il kernel corretto."
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
