# Base image with Flutter + Android SDK already installed
FROM instrumentisto/flutter:latest

# ----------------------------
# Install Rust toolchain (for cargokit)
# ----------------------------
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    pkg-config \
    libssl-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Rust environment
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=${PATH}:/usr/local/cargo/bin

RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain stable \
    && rustup component add rustfmt clippy

# Verify toolchain
RUN rustc --version && cargo --version

# ----------------------------
# Flutter project setup
# ----------------------------
WORKDIR /
