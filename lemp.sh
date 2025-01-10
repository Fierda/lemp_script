#!/bin/bash

# Create project directory structure
mkdir -p lemp-docker/{nginx,php,mysql,laravel}
cd lemp-docker

# Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    cat > .env << EOL
# Database Configuration
DB_ROOT_PASSWORD=admin
DB_DATABASE=laravel_db
DB_USERNAME=popo
DB_PASSWORD=baba4678
EOL
    echo "Created .env file with default credentials"
else
    echo "Using existing .env file"
fi

# Load environment variables
set -a
source .env
set +a

# Create docker-compose.yml
cat > docker-compose.yml << EOL
services:
  nginx:
    image: nginx:stable-alpine
    container_name: lemp-nginx
    ports:
      - "8220:80"
    volumes:
      - ./laravel:/var/www/html
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - php
    networks:
      - lemp-network

  php:
    build: ./php
    container_name: lemp-php
    volumes:
      - ./laravel:/var/www/html
    environment:
      DB_CONNECTION: mysql
      DB_HOST: lemp-mariadb
      DB_PORT: 3306
      DB_DATABASE: ${DB_DATABASE}
      DB_USERNAME: ${DB_USERNAME}
      DB_PASSWORD: ${DB_PASSWORD}
    networks:
      - lemp-network
    command: php-fpm # Make sure PHP-FPM is the entry point

  mariadb:
    image: mariadb:10.6
    container_name: lemp-mariadb
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
      MYSQL_DATABASE: ${DB_DATABASE}
      MYSQL_USER: ${DB_USERNAME}
      MYSQL_PASSWORD: ${DB_PASSWORD}
    volumes:
      - ./mysql:/var/lib/mysql
    networks:
      - lemp-network

networks:
  lemp-network:
    driver: bridge
EOL

# Create Dockerfile in the php directory
mkdir -p php
cat > php/Dockerfile << 'EOL'
FROM php:8.2-fpm-alpine

# Install dependencies
RUN apk add --no-cache \
    zip \
    unzip \
    git

# Install PHP extensions
RUN docker-php-ext-install pdo pdo_mysql

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

WORKDIR /var/www/html
EOL

# Create Nginx configuration
mkdir -p nginx
cat > nginx/default.conf << 'EOL'
server {
    listen 80;
    server_name localhost;
    root /var/www/html/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOL

function start_containers() {
    echo "Starting LEMP stack containers..."
    docker compose down -v 
    docker compose up -d --build

    echo "Waiting for containers to be ready..."
    sleep 10
}

function install_laravel() {
    echo "Installing Laravel..."
    
    rm -rf laravel/*
    rm -rf laravel/.git

    docker compose exec php composer create-project laravel/laravel /var/www/html --prefer-dist

    sleep 5

    # Configure Laravel
    docker compose exec php cp /var/www/html/.env.example /var/www/html/.env
    docker compose exec php php /var/www/html/artisan key:generate

    # Update Laravel .env file with the database settings
    docker compose exec php sed -i "s/DB_DATABASE=laravel/DB_DATABASE=${DB_DATABASE}/" /var/www/html/.env
    docker compose exec php sed -i "s/DB_USERNAME=root/DB_USERNAME=${DB_USERNAME}/" /var/www/html/.env
    docker compose exec php sed -i "s/DB_PASSWORD=/DB_PASSWORD=${DB_PASSWORD}/" /var/www/html/.env

    # Create necessary directories for storage and cache if they don't exist
    docker compose exec php mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache

    # Set the correct permissions for the storage and cache directories
    docker compose exec php chmod -R 777 /var/www/html/storage /var/www/html/bootstrap/cache
}



function customize_welcome_page() {
    echo "Customizing welcome page..."
    mkdir -p laravel/resources/views
    cat > laravel/resources/views/welcome.blade.php << 'EOL'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>This is Title !!!</title>
    <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.2.19/dist/tailwind.min.css" rel="stylesheet">
</head>
<body class="bg-gradient-to-br from-blue-900 to-black min-h-screen flex items-center justify-center">
    <div class="text-center">
        <h1 class="text-6xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-purple-500 mb-4">
            Hello F K A
        </h1>
        <p class="text-gray-300 text-xl max-w-md mx-auto leading-relaxed">
            Welcome to your custom Laravel application. Built with ❤️ using LEMP stack.
        </p>
        <div class="mt-8 space-x-4">
            <a href="https://laravel.com/docs" class="inline-block px-6 py-3 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors duration-300">
                Documentation
            </a>
            <a href="https://github.com/laravel" class="inline-block px-6 py-3 bg-purple-500 text-white rounded-lg hover:bg-purple-600 transition-colors duration-300">
                GitHub
            </a>
        </div>
    </div>
</body>
</html>
EOL
}

function check_status() {
    echo "Checking container status..."
    docker compose ps
    docker compose logs php 
    docker compose logs nginx
    docker compose logs mariadb
}

# Main execution
echo "Setting up LEMP stack with Laravel..."
start_containers
install_laravel
customize_welcome_page
check_status

echo -e "\nLEMP stack with Laravel setup complete!"

