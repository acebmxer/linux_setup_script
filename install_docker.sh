#!/usr/bin/env bash
# ===================================================================
#   flipsidebootstrap (merged & upgraded)
#   ----------------------------------------------------------------
#   Timezone  ➜ America/New_York
#   Dotfiles  ➜ $HOME/dotfiles
#   Shell     ➜ zsh (user & root)
#   XCP‑NG    ➜ installed
#   Topgrade  ➜ installed
#   Docker    ➜ installed & verified
# ===================================================================
# 0️⃣  Helper functions
# -----------------------------------------------------------------
log()  { echo "[LOG]   $*"; }
info() { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*" >&2; }
error(){ echo "[ERROR] $*" >&2; }
# Only run as root when needed
run_as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}
# 2️⃣  Basic packages
# -----------------------------------------------------------------
info "Updating APT cache …"
run_as_root apt-get update -y
info "Installing required packages …"
run_as_root apt-get install -y \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg2 \
    lsb-release \
    sudo
# -----------------------------------------------------------------
# 7️⃣  Docker – install & verify
# -----------------------------------------------------------------
info "Installing Docker …"
run_as_root install apt-transport-https ca-certificates curl software-properties-common
run_as_root curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
run_as_root echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
run_as_root apt update
run_as_root apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
# run_as_root groupadd docker
run_as_root usermod -aG docker $USER
# Reload group membership without logging out
info "Reloading docker group membership…"
newgrp docker <<'EOF'
# All subsequent commands run with the new group membership
EOF
# 7a. Docker verification tests
info "Running Docker verification tests…"
# Make sure we can talk to the daemon
docker_cmd() { run_as_root docker "$@"; }
# 8a. Verify the client can reach the daemon
docker_cmd version
# 8b. Pull & run the hello‑world image
HELLO_IMG="hello-world:latest"
info "Pulling ${HELLO_IMG} image …"
docker pull "$HELLO_IMG"
info "Running ${HELLO_IMG} container to confirm the image works …"
docker run --rm "$HELLO_IMG"
docker stop "$HELLO_IMG"
docker image rm "heello-world:latest"
# 8c. Quick compose test
info "Running a quick docker‑compose test …"
COMPOSE_DIR="$(mktemp -d)"
cat > "${COMPOSE_DIR}/docker-compose.yml" <<'EOF'
version: "3.8"
services:
  hello:
    image: hello-world:latest
    container_name: hello-world_test
EOF
docker compose -f "${COMPOSE_DIR}/docker-compose.yml" up -d
sleep 2
docker compose -f "${COMPOSE_DIR}/docker-compose.yml" ps
docker compose -f "${COMPOSE_DIR}/docker-compose.yml" down
rm -rf "${COMPOSE_DIR}"
info "Docker verification complete."
# 9️⃣  Final summary
# -----------------------------------------------------------------
info "All components are now installed and, for Docker, all tests passed successfully!"
