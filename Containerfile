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

# bootc lint is strict about runtime-only directories. Remove only the known
# transient runtime content created during package installation and leave the
# systemd-managed /run entries alone; deleting /run/* triggers "Device or resource busy".
RUN rm -rf /run/gluster /tmp/* /var/tmp/* && \
    find /usr/sbin /usr/bin -maxdepth 1 -type l -exec sh -c 'for p do t=$(readlink "$p" 2>/dev/null || true); case "$t" in /*) [ -e "$t" ] || rm -f "$p" ;; esac; done' sh {} + && \
    for p in /usr/sbin/chcon /usr/bin/chcon; do [ -L "$p" ] && rm -f "$p"; done && \
    mkdir -p /run /tmp /var/tmp && \
    chmod 1777 /tmp /var/tmp && \
    true

### LINTING
RUN bootc container lint
