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
## 2b. XPADNEO: risolvi il pacchetto headers del kernel nel repo, NON a mano
## ==========================================
# La nomenclatura del kernel di base patchato da RakuOS non coincide sempre con il
# nome del pacchetto headers del repo. Per questo non costruire un nome hardcoded
# come kernel-devel-7.2.6-rakuos... o kernel-devel-matched a prescindere:
# si deve rilevare il pacchetto effettivamente presente nel repo e usare quello.
KERNEL_IMAGE_VERSION="${KERNEL_IMAGE_VERSION:-$(uname -r 2>/dev/null || echo 'unknown')}"

detect_kernel_devel_pkg() {
    local pkg
    for pkg in kernel-devel-matched kernel-devel; do
        if dnf repoquery --quiet --latest-limit 1 "${pkg}" >/dev/null 2>&1; then
            dnf repoquery --latest-limit 1 --qf '%{name}-%{version}-%{release}.%{arch}' "${pkg}" | head -n 1
            return 0
        fi
    done

    local found
    found="$(dnf repoquery --latest-limit 1 --qf '%{name}-%{version}-%{release}.%{arch}' 'kernel-devel*' 2>/dev/null | head -n 1 || true)"
    if [[ -n "${found}" ]]; then
        printf '%s\n' "${found}"
        return 0
    fi

    return 1
}

KERNEL_DEVEL_PKG="$(detect_kernel_devel_pkg || true)"
if [[ -z "${KERNEL_DEVEL_PKG}" ]]; then
    echo "FATAL: nessun pacchetto kernel-devel disponibile nel repo di RakuOS."
    echo "Controllo disponibili:"
    dnf list --available 'kernel-devel*' 2>/dev/null || true
    exit 1
fi

KERNEL_DEVEL_VERSION="$(dnf repoquery --latest-limit 1 --qf '%{version}-%{release}.%{arch}' "${KERNEL_DEVEL_PKG}" 2>/dev/null | head -n 1 || true)"
if [[ -z "${KERNEL_DEVEL_VERSION}" ]]; then
    KERNEL_DEVEL_VERSION="${KERNEL_DEVEL_PKG#kernel-devel-}"
fi

if [[ -z "${KERNEL_DEVEL_VERSION}" ]]; then
    echo "FATAL: impossibile risolvere la versione del kernel-devel per ${KERNEL_DEVEL_PKG}."
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
