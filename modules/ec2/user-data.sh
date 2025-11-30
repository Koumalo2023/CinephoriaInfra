#!/bin/bash
# User data script for Cinephoria EC2 instance

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl enable docker
systemctl start docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Nginx
amazon-linux-extras install nginx1 -y
systemctl enable nginx
systemctl start nginx

# Create application directory
mkdir -p /opt/cinephoria

# Create docker-compose file for backend
cat << EOF > /opt/cinephoria/docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:15
    container_name: cinephoria-postgres
    environment:
      POSTGRES_DB: CinephoriaDB
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${postgres_password}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  backend-prod:
    image: cinephoria-backend:latest
    container_name: cinephoria-backend-prod
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ConnectionStrings__PostgreSql=Host=postgres;Port=5432;Database=CinephoriaDB_Production;Username=postgres;Password=${postgres_password}
    ports:
      - "5000:8080"
    depends_on:
      - postgres
    restart: unless-stopped

  backend-staging:
    image: cinephoria-backend:latest
    container_name: cinephoria-backend-staging
    environment:
      - ASPNETCORE_ENVIRONMENT=Staging
      - ConnectionStrings__PostgreSql=Host=postgres;Port=5432;Database=CinephoriaDB_Staging;Username=postgres;Password=${postgres_password}
    ports:
      - "5001:8080"
    depends_on:
      - postgres
    restart: unless-stopped

volumes:
  postgres_data:
EOF

# Create Nginx configuration
cat << EOF > /etc/nginx/conf.d/cinephoria.conf
server {
    listen 80;
    server_name api.${domain_name};
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 80;
    server_name staging-api.${domain_name};
    
    location / {
        proxy_pass http://localhost:5001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Reload Nginx
nginx -t && systemctl reload nginx

# Pull and start Docker containers
cd /opt/cinephoria
docker-compose pull
docker-compose up -d

echo "Cinephoria infrastructure setup completed!"