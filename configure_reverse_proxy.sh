# Check if certbot is installed
if ! command -v certbot &>/dev/null; then
    echo "certbot is not installed. Installing certbot..."
    sudo apt-get update
    sudo apt-get install -y certbot
else
    echo "certbot is already installed."
fi

# Function to obtain SSL certificate
obtain_ssl_certificate() {
    domain=$1
    sudo certbot certonly --standalone -d "$domain" --non-interactive --agree-tos --email olden@la-tribu.xyz
}

# Obtain SSL certificates
echo "Obtaining SSL certificates..."

if [ ! -d "/etc/letsencrypt/live/explorer.kred.la-tribu.xyz" ]; then
    obtain_ssl_certificate "explorer.kred.la-tribu.xyz"
else
    echo "SSL certificate for explorer.kred.la-tribu.xyz already exists."
fi

if [ ! -d "/etc/letsencrypt/live/stats.kred.la-tribu.xyz" ]; then
    obtain_ssl_certificate "stats.kred.la-tribu.xyz"
else
    echo "SSL certificate for stats.kred.la-tribu.xyz already exists."
fi

if [ ! -d "/etc/letsencrypt/live/visualizer.kred.la-tribu.xyz" ]; then
    obtain_ssl_certificate "visualizer.kred.la-tribu.xyz"
else
    echo "SSL certificate for visualizer.kred.la-tribu.xyz already exists."
fi