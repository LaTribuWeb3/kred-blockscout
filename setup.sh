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
    local exposed_443_port=$(docker inspect -f '{{(index (index .NetworkSettings.Ports "443/tcp") 0).HostPort}}' blockscout-l2-${port_prefix}-proxy)
    local exposed_8080_port=$(docker inspect -f '{{(index (index .NetworkSettings.Ports "8080/tcp") 0).HostPort}}' blockscout-l2-${port_prefix}-proxy)
    local config_file="/etc/nginx/sites-enabled/blockscout-l2-${port_prefix}"
    
    # Create the configuration content
    cat > "$config_file" << EOL
# stats.${domain_base} configuration
server {
    listen 80;
    server_name stats.${domain_base};

    location / {
        proxy_pass http://localhost:${exposed_8080_port};
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
        proxy_pass https://localhost:${exposed_443_port};
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
        proxy_pass http://localhost:${exposed_8080_port};
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
        proxy_pass https://localhost:${exposed_443_port};
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
        proxy_pass http://localhost:${exposed_8080_port};
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
        proxy_pass https://localhost:${exposed_443_port};
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
    
    # Check for existing containers and remove them if found
    existing_containers=$(docker ps -q --filter "name=$project_name-backend")
    if [ -n "$existing_containers" ]; then
        echo "Stopping backend containers for $project_name..."
        for container in $existing_containers; do
            docker kill "$container"
            check_status "Backend container stop for $container"
        done
    fi

    mkdir -p $PWD/docker-compose/services/volumes/${project_name}-db-data
    chown -R 2000:2000 $PWD/docker-compose/services/volumes/${project_name}-db-data

    mkdir -p $PWD/docker-compose/services/volumes/${project_name}-stats-db-data
    chown -R 2000:2000 $PWD/docker-compose/services/volumes/${project_name}-stats-db-data
    
    # Start docker compose with project name
    cd /root/kred-blockscout/docker-compose
    DOMAIN_BASE=$domain_base PORT_PREFIX=$port_prefix docker compose -p $project_name down -v || true
    DOMAIN_BASE=$domain_base PORT_PREFIX=$port_prefix docker compose -p $project_name up -d
    cd -

    sleep 5
    
    # Generate Nginx configuration
    generate_nginx_config "$domain_base" "$instance_number"
    
    # Start nginx after certificate generation
    echo "Starting nginx service..."
    systemctl start nginx
    check_status "Nginx start"
    
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

# Replace the fixed loop with argument handling
if [ $# -eq 0 ]; then
    # No arguments provided - deploy all instances (original behavior)
    for i in {1..5}; do
        deploy_instance "$i"
    done
else
    # Deploy only specified instances
    for instance in "$@"; do
        deploy_instance "$instance"
    done
fi

echo "✨ All instances have been deployed successfully!"