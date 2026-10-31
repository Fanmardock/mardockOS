# Global build arg available to all FROM lines for image tag resolution.
ARG BASE_IMAGE_TAG="${BASE_IMAGE_TAG:-latest}"
ARG BASE_IMAGE_REPO="quay.io/rakuos/rakuos-base-v3"

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ${BASE_IMAGE_REPO}:${BASE_IMAGE_TAG}

### ISA LEVEL & OCI LABELS (x86-64-v3)
LABEL os.isa_level="v3"
LABEL org.opencontainers.image.base.isa="v3"

RUN sed -i 's/^ID=.*/ID=fedora/' /etc/os-release && \
    echo "ISA_LEVEL=v3" >> /etc/os-release

### MODIFICATIONS
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /

RUN --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /usr/bin/systemctl preset brew-setup.service && \
    /usr/bin/systemctl preset brew-update.timer && \
    /usr/bin/systemctl preset brew-upgrade.timer

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### FIX FOR bootc CONTAINER LINT
# bootc richiede che i symlink restino dentro il rootfs.
# Se un path punta fuori dal filesystem (es. /usr/sbin/chcon -> /etc/alternatives/chcon
# oppure un symlink esterno al rootfs), il lint fallisce con:
# "a path led outside of the filesystem"
RUN set -eux; \
    # Rimuove symlink rotti o che puntano fuori dal rootfs
    find /usr /bin /sbin -xdev -type l -print0 | while IFS= read -r -d '' link; do \
        target="$(readlink "$link" 2>/dev/null || true)"; \
        case "$target" in \
            /|/usr/*|/bin/*|/sbin/*|/etc/*|/var/*|/opt/*|/lib*|/root*|/home*) ;; \
            *) rm -f "$link" ;; \
        esac; \
    done; \
    # Garantisce che chcon sia dentro al rootfs
    if [ -e /usr/bin/chcon ] && [ ! -e /usr/sbin/chcon ]; then \
        ln -sf ../bin/chcon /usr/sbin/chcon; \
    fi; \
    # Se esiste ma punta fuori dal rootfs, lo corregge
    if [ -L /usr/sbin/chcon ]; then \
        resolved="$(readlink -f /usr/sbin/chcon 2>/dev/null || true)"; \
        case "$resolved" in \
            /usr/*|/bin/*|/sbin/*) ;; \
            *) rm -f /usr/sbin/chcon; ln -sf ../bin/chcon /usr/sbin/chcon ;; \
        esac; \
    fi; \
    # Verifica finale: chcon deve risolvere dentro il rootfs
    realpath /usr/sbin/chcon >/dev/null 2>&1 || exit 1

### LINTING
RUN bootc container lint
