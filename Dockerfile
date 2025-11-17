FROM debian:bookworm-slim

# Update package list and install required dependencies
RUN apt-get update && \
    apt-get install -y \
    curl \
    xz-utils \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create a user with UID 1000 and GID 1000
RUN groupadd -g 1000 nixuser && \
    useradd -m -u 1000 -g 1000 -s /bin/bash nixuser && \
    echo "nixuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to the new user
USER nixuser
WORKDIR /home/nixuser

# Install Nix package manager (single-user installation)
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

# Configure environment for Nix
ENV PATH="/home/nixuser/.nix-profile/bin:${PATH}"
RUN echo '. /home/nixuser/.nix-profile/etc/profile.d/nix.sh' >> /home/nixuser/.bashrc

# Enable experimental features (nix-command and flakes)
RUN mkdir -p /home/nixuser/.config/nix && \
    echo "experimental-features = nix-command flakes" > /home/nixuser/.config/nix/nix.conf

# Set default command
CMD ["/bin/bash"]
