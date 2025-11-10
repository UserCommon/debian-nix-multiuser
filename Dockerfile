FROM debian:bookworm-slim

# Установка необходимых зависимостей и локалей
RUN apt-get update && apt-get install -y \
    curl \
    xz-utils \
    git \
    sudo \
    ca-certificates \
    locales \
    && rm -rf /var/lib/apt/lists/*

# Настройка UTF-8 локали для поддержки русского языка
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    sed -i '/ru_RU.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen en_US.UTF-8 ru_RU.UTF-8 && \
    update-locale LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8

# Установка переменных окружения для UTF-8
ENV LANG=ru_RU.UTF-8 \
    LC_ALL=ru_RU.UTF-8 \
    LANGUAGE=ru_RU:ru \
    LC_CTYPE=ru_RU.UTF-8

# Установка Nix в multi-user режиме (создаст все необходимые группы и пользователей)
RUN curl --proto '=https' --tlsv1.2 -sSfL https://nixos.org/nix/install | sh -s -- --daemon

# Настройка окружения для Nix
ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"
ENV NIX_PATH="/nix/var/nix/profiles/per-user/root/channels"

# Включение экспериментальных фич (flakes, nix-command)
RUN mkdir -p /etc/nix && \
    echo "experimental-features = nix-command flakes" > /etc/nix/nix.conf

# Создание непривилегированного пользователя и добавление в группу nixbld
RUN useradd -m -s /bin/bash user && \
    usermod -aG nixbld user && \
    echo "user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Настройка для работы Nix daemon
RUN mkdir -p /etc/systemd/system && \
    ln -s /nix/var/nix/profiles/default/lib/systemd/system/nix-daemon.service \
    /etc/systemd/system/ || true

# Скрипт запуска Nix daemon (должен запускаться от root)
COPY <<'EOF' /usr/local/bin/start-nix-daemon
#!/bin/bash
set -e

# Исправление прав доступа к сокету
mkdir -p /nix/var/nix/daemon-socket
chmod 755 /nix/var/nix/daemon-socket

# Запуск Nix daemon от root в фоне
su -c "/nix/var/nix/profiles/default/bin/nix-daemon &" root

# Ожидание запуска daemon
sleep 2

# Переключение на пользователя и выполнение команды
if [ "$(id -u)" = "0" ]; then
    exec su - user -c "$*"
else
    exec "$@"
fi
EOF

RUN chmod +x /usr/local/bin/start-nix-daemon

# Переключение на непривилегированного пользователя
# (но entrypoint запустится от root для daemon)
WORKDIR /home/user

# Настройка окружения для пользователя
RUN echo 'export PATH="/nix/var/nix/profiles/default/bin:$PATH"' >> ~/.bashrc && \
    echo 'export NIX_PATH="/nix/var/nix/profiles/per-user/root/channels"' >> ~/.bashrc && \
    echo 'export LANG=ru_RU.UTF-8' >> ~/.bashrc && \
    echo 'export LC_ALL=ru_RU.UTF-8' >> ~/.bashrc

# Точка входа
ENTRYPOINT ["/usr/local/bin/start-nix-daemon"]
CMD ["/bin/bash"]
