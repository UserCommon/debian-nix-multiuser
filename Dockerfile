FROM debian:bookworm-slim

# Update package list and install required dependencies
RUN apt-get update && \
    apt-get install -y \
    curl \
    xz-utils \
    git \
    sudo \
    ca-certificates \
    locales \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create a user with UID 1000 and GID 1000
RUN groupadd -g 1000 user && \
    useradd -m -u 1000 -g 1000 -s /bin/bash user && \
    echo "user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to the new user
USER user
WORKDIR /home/user

# Install Nix package manager (single-user installation)
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

# Configure environment for Nix
ENV PATH="/home/user/.nix-profile/bin:${PATH}"
RUN echo '. /home/user/.nix-profile/etc/profile.d/nix.sh' >> /home/user/.bashrc

# Enable experimental features (nix-command and flakes)
RUN mkdir -p /home/user/.config/nix && \
    echo "experimental-features = nix-command flakes" > /home/user/.config/nix/nix.conf

# Set default command
CMD ["/bin/bash"]
