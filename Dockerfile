# Base image with Flutter + Android SDK already installed
FROM instrumentisto/flutter:latest

# ----------------------------
# Install Rust toolchain (for cargokit)
# ----------------------------
RUN apt-get update && apt-get install -y \
    curl \
    socat \
    build-essential \
    pkg-config \
    libssl-dev \
    openssh-server \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download Helix latest .deb and install
RUN curl -Lo helix.deb https://github.com/helix-editor/helix/releases/download/25.07.1/helix_25.7.1-1_amd64.deb \
    && dpkg -i helix.deb \
    && rm helix.deb

# Create SSH runtime directory
RUN mkdir -p /run/sshd
RUN echo 'root:root' | chpasswd
RUN sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Rust environment
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=${PATH}:/usr/local/cargo/bin
ENV TERM=alacritty
ENV COLORTERM=truecolor

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain stable \
    && rustup component add rustfmt clippy rust-analyzer rust-src

# Verify toolchain
RUN rustc --version && cargo --version

# ----------------------------
# Flutter project setup
# ----------------------------
WORKDIR /

# Start SSHD
CMD ["/usr/sbin/sshd", "-D"]
