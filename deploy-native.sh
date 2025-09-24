#!/bin/bash

# Native deployment script - installs and runs applications directly on the server
# without using Docker containers

set -e

echo "Starting native deployment..."

# Install required software
echo "Installing required software..."
sudo apt-get update -y

# Install Java 17
echo "Installing Java 17..."
sudo apt-get install -y openjdk-17-jdk

# Install Maven
echo "Installing Maven..."
sudo apt-get install -y maven

# Install Node.js 18
echo "Installing Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install nginx
echo "Installing nginx..."
sudo apt-get install -y nginx

# Install git if not present
if ! command -v git &> /dev/null; then
    echo "Installing git..."
    sudo apt-get install -y git
fi

# Create application directories
echo "Creating application directories..."
sudo mkdir -p /opt/arbeit
sudo mkdir -p /opt/arbeit/backend
sudo mkdir -p /opt/arbeit/frontend
sudo mkdir -p /var/log/arbeit

# Clone and build backend
echo "Building backend application..."
cd /opt/arbeit/backend
if [ ! -d "springboot-backend" ]; then
    git clone https://github.com/PavanKarthikGaraga/Arbeit-cicd.git .
fi

cd springboot-backend
mvn clean package -DskipTests

# Find the built JAR file
JAR_FILE=$(find target -name "*.war" | head -1)
if [ -z "$JAR_FILE" ]; then
    echo "ERROR: No WAR file found in target directory"
    exit 1
fi

# Clone and build frontend
echo "Building frontend application..."
cd /opt/arbeit/frontend
if [ ! -d "my-app" ]; then
    git clone https://github.com/PavanKarthikGaraga/Arbeit-cicd.git .
fi

cd my-app
npm install
NEXT_PUBLIC_API_URL=http://localhost:9090/api npm run build

# Create systemd service for backend
echo "Creating backend systemd service..."
sudo tee /etc/systemd/system/arbeit-backend.service > /dev/null <<EOF
[Unit]
Description=Arbeit Backend Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/arbeit/backend/springboot-backend
ExecStart=/usr/bin/java -jar $JAR_FILE
Environment="SPRING_DATASOURCE_URL=jdbc:mysql://13.221.25.150:3306/arbeit?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true"
Environment="SPRING_DATASOURCE_USERNAME=root"
Environment="SPRING_DATASOURCE_PASSWORD=adminadmin"
Environment="SERVER_PORT=9090"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for frontend
echo "Creating frontend systemd service..."
sudo tee /etc/systemd/system/arbeit-frontend.service > /dev/null <<EOF
[Unit]
Description=Arbeit Frontend Service
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/arbeit/frontend/my-app
ExecStart=/usr/bin/npm start
Environment="PORT=3000"
Environment="NODE_ENV=production"
Environment="NEXT_PUBLIC_API_URL=http://localhost:9090/api"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Configure nginx
echo "Configuring nginx..."
sudo cp /home/ubuntu/arbeit-deployment/nginx.conf /etc/nginx/nginx.conf

# Enable and start services
echo "Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable arbeit-backend
sudo systemctl enable arbeit-frontend
sudo systemctl enable nginx

sudo systemctl start arbeit-backend
sudo systemctl start arbeit-frontend
sudo systemctl start nginx

echo "Deployment completed successfully!"
echo "Services status:"
sudo systemctl status arbeit-backend --no-pager -l
sudo systemctl status arbeit-frontend --no-pager -l
sudo systemctl status nginx --no-pager -l

echo ""
echo "Application URLs:"
echo "- Frontend: http://your-server-ip/"
echo "- Backend API: http://your-server-ip/api/"
echo "- Health check: http://your-server-ip/api/actuator/health"
