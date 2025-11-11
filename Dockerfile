FROM debian:bookworm-slim

# --- Install dependencies and locales ---
RUN apt-get update && apt-get install -y \
    curl \
    xz-utils \
    git \
    sudo \
    ca-certificates \
    locales \
    && rm -rf /var/lib/apt/lists/*

# --- UTF-8 locales (ru + en) ---
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    sed -i '/ru_RU.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen en_US.UTF-8 ru_RU.UTF-8 && \
    update-locale LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8

ENV LANG=ru_RU.UTF-8 \
    LC_ALL=ru_RU.UTF-8 \
    LANGUAGE=ru_RU:ru \
    LC_CTYPE=ru_RU.UTF-8

# --- Install Nix in multi-user mode ---
RUN curl --proto '=https' --tlsv1.2 -sSfL https://nixos.org/nix/install | sh -s -- --daemon

ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"
ENV NIX_PATH="/nix/var/nix/profiles/per-user/root/channels"

RUN mkdir -p /etc/nix && \
    echo "experimental-features = nix-command flakes" > /etc/nix/nix.conf

# --- Create unprivileged user ---
RUN useradd -m -s /bin/bash user && \
    usermod -aG nixbld user && \
    echo "user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# --- Prepare per-user and daemon paths ---
RUN mkdir -p \
    /nix/var/nix/daemon-socket \
    /nix/var/nix/profiles/per-user/user \
    /nix/var/nix/gcroots/per-user/user && \
    chown -R user:nixbld /nix/var/nix && \
    chmod -R 775 /nix/var/nix/daemon-socket && \
    chmod -R 775 /nix/var/nix/profiles/per-user/user && \
    chmod -R 775 /nix/var/nix/gcroots/per-user/user

# --- Optional: ensure nix-daemon service file exists (some Nix versions miss it) ---
RUN mkdir -p /etc/systemd/system && \
    ln -sf /nix/var/nix/profiles/default/lib/systemd/system/nix-daemon.service \
    /etc/systemd/system/nix-daemon.service || true

# --- ENTRYPOINT ---
COPY <<'EOF' /usr/local/bin/start-nix-daemon
#!/usr/bin/env bash
set -euo pipefail

echo "[entrypoint] Starting Nix daemon as root..."
/nix/var/nix/profiles/default/bin/nix-daemon & disown

# Give the daemon time to initialize
sleep 2

echo "[entrypoint] Nix daemon started successfully."
echo "[entrypoint] You are root. Nix is ready for both root and user sessions."

exec "$@"
EOF

RUN chmod +x /usr/local/bin/start-nix-daemon

# --- Default: stay as root, but nix works for all users ---
ENTRYPOINT ["/usr/local/bin/start-nix-daemon"]
CMD ["/bin/bash"]
