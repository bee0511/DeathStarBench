#!/bin/bash

set -e

echo "[*] Starting CS538 full environment setup..."

# ==== Go ====
if command -v go &>/dev/null; then
    echo "[✔] Go already installed: $(go version)"
else
    ARCH=$(uname -m)
    GO_VERSION=1.24.2

    if [ "$ARCH" = "x86_64" ]; then
        GO_ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ]; then
        GO_ARCH="arm64"
    else
        echo "[!] Unsupported architecture: $ARCH"
        exit 1
    fi

    echo "[*] Installing Go for $GO_ARCH..."
    wget https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf go${GO_VERSION}.linux-${GO_ARCH}.tar.gz
    rm go${GO_VERSION}.linux-${GO_ARCH}.tar.gz
fi

# ==== Go env ====
echo "[*] Setting Go environment variables..."
grep -qxF 'export PATH=$PATH:/usr/local/go/bin' ~/.bashrc || echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
grep -qxF 'export GOPATH=$HOME/go' ~/.bashrc || echo 'export GOPATH=$HOME/go' >> ~/.bashrc
grep -qxF 'export PATH=$PATH:$GOPATH/bin' ~/.bashrc || echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.bashrc
source ~/.bashrc
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin

# ==== System tools ====
echo "[*] Installing basic tools..."
sudo apt update
sudo apt install -y git curl build-essential make libssl-dev tmux htop ca-certificates gnupg lsb-release

# ==== Python + pip packages ====
echo "[*] Installing Python tools..."
sudo apt install -y python3-pip

# Install all required Python packages
# pip3 install --user -r ~/cs538/requirements.txt

# ==== LuaRocks and LuaSocket ====
echo "[*] Installing LuaRocks and luasocket..."
sudo apt install -y luarocks
sudo luarocks install luasocket

# ==== Docker and Docker Compose ====
echo "[*] Installing Docker and Docker Compose..."

# Add Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker apt repo
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Install legacy docker-compose binary
if ! command -v docker-compose &>/dev/null; then
  echo "[*] Installing legacy docker-compose..."
  sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi
sudo usermod -aG docker $USER

# ==== NGINX ====
if ! command -v nginx &>/dev/null; then
    echo "[*] Installing NGINX..."
    sudo apt install -y nginx
else
    echo "[✔] NGINX already installed"
fi

# ==== Mahimahi ====
if ! command -v mm-webrecord &>/dev/null; then
    echo "[*] Installing Mahimahi..."
    sudo apt install -y mahimahi
else
    echo "[✔] Mahimahi already installed"
fi

# ==== hey ====
if ! command -v hey &>/dev/null; then
    echo "[*] Installing hey..."
    go install github.com/rakyll/hey@latest
else
    echo "[✔] hey already installed"
fi

# ==== Fortio ====
if ! command -v fortio &>/dev/null; then
    echo "[*] Installing Fortio..."
    go install fortio.org/fortio@latest
else
    echo "[✔] Fortio already installed"
fi


# ==== wrk2 from DeathStarBench ====
if ! command -v wrk &>/dev/null || ! wrk --version 2>/dev/null | grep -q wrk2; then
    echo "[*] Installing wrk2 from DeathStarBench fork..."
    cd ./wrk2
    git submodule update --init --recursive
    make
    sudo cp wrk /usr/local/bin/
    cd ~
else
    echo "[✔] wrk2 already installed"
fi

echo "[+] Setup complete! You may want to run 'sudo usermod -aG docker $USER' then log out/in to use Docker without sudo."
