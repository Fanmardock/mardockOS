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
## 2b. XPADNEO: compila contro il kernel RPM esatto del sistema
## ==========================================
# Importante:
# su RakuOS/Fedora il nome del pacchetto kernel-devel NON è uguale a uname -r.
# Bisogna usare il nome RPM del kernel-core, cioè VERSION-RELEASE.ARCH.
KERNEL_RPM="$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null || uname -r)"
KERNEL_DEVEL_PKG="kernel-devel-${KERNEL_RPM}"

echo "Kernel RPM del sistema: ${KERNEL_RPM}"
echo "Kernel-devel richiesto: ${KERNEL_DEVEL_PKG}"

if ! rpm -q "${KERNEL_DEVEL_PKG}" >/dev/null 2>&1; then
    echo "FATAL: ${KERNEL_DEVEL_PKG} non è presente nel repo di RakuOS."
    echo "Il repo non ha ancora il kernel-devel compatibile per il kernel attuale."
    echo "Non usare un kernel diverso: il modulo deve essere costruito contro il kernel esatto."
    exit 1
fi

rum install -y \
    dkms \
    gcc \
    make \
    git \
    "${KERNEL_DEVEL_PKG}" \
    akmod-xpadneo

# Costruzione del modulo contro il kernel preciso dell'immagine.
akmods --force --rebuild --kernels "${KERNEL_RPM}"

# Verifica che il modulo sia realmente presente.
if ! find "/lib/modules/${KERNEL_RPM}" -type f \( -iname '*xpadneo*.ko*' -o -iname '*xpad*.ko*' \) | grep -q .; then
    echo "ERROR: nessun modulo xpadneo costruito in /lib/modules/${KERNEL_RPM}."
    exit 1
fi

mkdir -p /etc/modules-load.d/
printf '%s\n' "hid-xpadneo" > /etc/modules-load.d/xpadneo.conf

# Prova il caricamento; se fallisce, il build è comunque corretto ma il kernel non ha ancora il modulo pronto.
modprobe xpadneo || {
    echo "WARNING: modprobe xpadneo fallito in build phase; il modulo è stato comunque costruito per il kernel corretto."
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
