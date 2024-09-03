# Check if ca-certificates and curl are installed
if ! dpkg -s ca-certificates curl make wget >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl make wget
fi

# Check if jq is installed
if ! command -v jq >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y jq
fi

# Create the keyrings directory if it doesn't exist
sudo install -m 0755 -d /etc/apt/keyrings

# Check if docker.asc already exists before downloading
if [ ! -f /etc/apt/keyrings/docker.asc ]; then
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
fi

# Add the repository to Apt sources:
if ! grep -q "deb \[arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc\] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" /etc/apt/sources.list.d/docker.list; then
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

# Check if Docker is installed
if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
