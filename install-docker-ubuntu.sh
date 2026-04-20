#!/usr/bin/env bash
set -Eeuo pipefail

install_from_official_repo() {
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg

  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_from_ubuntu_repo() {
  sudo apt-get update
  sudo apt-get install -y docker.io docker-buildx docker-compose-v2
}

if ! install_from_official_repo; then
  echo
  echo "Official Docker repository installation failed, falling back to Ubuntu packages..."
  install_from_ubuntu_repo
fi

sudo usermod -aG docker "$USER"

echo
echo "Docker installation finished."
echo "Reconnect to the server once so the new docker group membership takes effect."
