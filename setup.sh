#!/bin/bash

set -e

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        echo "✅ $1 successful"
    else
        echo "❌ $1 failed"
        exit 1
    fi
}

# Function to generate nginx configuration
generate_nginx_config() {
    local domain_base=$1
    local port_prefix=$2
    local config_file="/etc/nginx/sites-enabled/blockscout-l2-${port_prefix}"
    
    # Create the configuration content
    cat > "$config_file" << EOL
# stats.${domain_base} configuration
server {
    listen 80;
    server_name stats.${domain_base};

    location / {
        proxy_pass http://localhost:${port_prefix}8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}

server {
    listen 443 ssl;
    server_name stats.${domain_base};

    ssl_certificate /etc/letsencrypt/live/stats.${domain_base}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/stats.${domain_base}/privkey.pem;

    location / {
        proxy_pass https://localhost:${port_prefix}443;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}

# visualizer.${domain_base} configuration
server {
    listen 80;
    server_name visualizer.${domain_base};

    location / {
        proxy_pass http://localhost:${port_prefix}8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}

server {
    listen 443 ssl;
    server_name visualizer.${domain_base};

    ssl_certificate /etc/letsencrypt/live/visualizer.${domain_base}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/visualizer.${domain_base}/privkey.pem;

    location / {
        proxy_pass https://localhost:${port_prefix}443;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}

# blockscout.${domain_base} configuration
server {
    listen 80;
    server_name blockscout.${domain_base};

    location / {
        proxy_pass http://localhost:${port_prefix}8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}

server {
    listen 443 ssl;
    server_name blockscout.${domain_base};

    ssl_certificate /etc/letsencrypt/live/blockscout.${domain_base}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/blockscout.${domain_base}/privkey.pem;

    location / {
        proxy_pass https://localhost:${port_prefix}443;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOL

    check_status "Nginx configuration generation for ${domain_base}"
}

# Function to update repository
update_repository() {
    echo "Updating kred-blockscout repository..."
    cd /root/kred-blockscout
    git pull
    check_status "Repository update"
    cd -
}

# Function to deploy a single instance
deploy_instance() {
    local instance_number=$1
    local project_name="blockscout-l2-$instance_number"
    local domain_base="l2.$instance_number.relend.la-tribu.xyz"
    local port_prefix=$((instance_number + 1))
    
    echo "Deploying instance $instance_number with domain base: $domain_base"
    
    # Create temporary env file
    export DOMAIN_BASE=$domain_base
    export PORT_PREFIX=$port_prefix
    
    # Stop nginx before certificate generation
    if systemctl is-active --quiet nginx; then
        echo "Stopping nginx service..."
        systemctl stop nginx
        check_status "Nginx stop"
    fi
    
    # Generate SSL certificates for the domains
    domains=(
        "blockscout.${domain_base}"
        "visualizer.${domain_base}"
        "stats.${domain_base}"
    )
    
    for domain in "${domains[@]}"; do
        if [ ! -d "/etc/letsencrypt/live/$domain" ]; then
            echo "Generating SSL certificate for $domain..."
            certbot certonly --standalone \
                -d "$domain" \
                --agree-tos \
                --email olden@la-tribu.xyz \
                -n
            check_status "SSL certificate generation for $domain"
        else
            echo "✅ SSL certificate already exists for $domain"
        fi
    done
    
    # Generate Nginx configuration
    generate_nginx_config "$domain_base" "$port_prefix"
    
    # Start nginx after certificate generation
    echo "Starting nginx service..."
    systemctl start nginx
    check_status "Nginx start"
    
    # Check for existing containers and remove them if found
    existing_containers=$(docker ps -q --filter "name=$project_name-backend-1")
    if [ -n "$existing_containers" ]; then
        echo "Stopping backend containers for $project_name..."
        for container in $existing_containers; do
            docker kill "$container"
            check_status "Backend container stop for $container"
        done
    fi
    
    # Start docker compose with project name
    cd /root/kred-blockscout/docker-compose
    DOMAIN_BASE=$domain_base PORT_PREFIX=$port_prefix docker compose -p $project_name down -v || true
    DOMAIN_BASE=$domain_base PORT_PREFIX=$port_prefix docker compose -p $project_name up -d
    cd -
    
    check_status "Docker compose deployment for instance $instance_number"
}

# Install required dependencies
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    apt-get update
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo \
        "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    check_status "Docker installation"
fi

if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..."
    apt-get update
    apt-get install -y certbot
    check_status "Certbot installation"
fi

# Update repository before deployment
update_repository

for i in {1..5}; do
    deploy_instance "$i"
done

echo "✨ Both instances have been deployed successfully!"