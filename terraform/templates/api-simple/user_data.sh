#!/bin/bash
# API Simple Module - User Data Script
# Configures EC2 instance for API service hosting

set -e

# Variables passed from Terraform
API_NAME="${api_name}"
RUNTIME="${runtime}"
API_PORT="${api_port}"
ENVIRONMENT="${environment}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /var/log/api-setup.log
}

log "=== Starting API Service Setup ==="
log "API Name: $API_NAME"
log "Runtime: $RUNTIME"
log "Environment: $ENVIRONMENT"
log "Port: $API_PORT"

# Update system
log "Updating system packages..."
yum update -y

# Install common dependencies
log "Installing common dependencies..."
yum install -y git curl wget unzip htop tmux nginx

# Install Docker for containerized deployment
log "Installing Docker..."
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
log "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install runtime-specific dependencies
case "$RUNTIME" in
    "nodejs")
        log "Installing Node.js..."
        curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
        yum install -y nodejs
        npm install -g pm2
        ;;
    "python")
        log "Installing Python..."
        yum install -y python3 python3-pip python3-venv
        pip3 install --upgrade pip
        pip3 install gunicorn uvicorn fastapi flask
        ;;
    "java")
        log "Installing Java..."
        yum install -y java-11-openjdk java-11-openjdk-devel maven
        ;;
    "go")
        log "Installing Go..."
        cd /tmp
        wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
        tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
        ;;
esac

# Create application directory
log "Setting up application directory..."
mkdir -p /opt/$API_NAME
chown ec2-user:ec2-user /opt/$API_NAME

# Create basic application structure based on runtime
cd /opt/$API_NAME

case "$RUNTIME" in
    "nodejs")
        log "Creating Node.js application template..."
        cat > package.json << 'EOF'
{
  "name": "${API_NAME}",
  "version": "1.0.0",
  "description": "API Service created by Internal Developer Platform",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^6.1.5",
    "dotenv": "^16.0.3"
  },
  "devDependencies": {
    "nodemon": "^2.0.22",
    "jest": "^29.5.0"
  }
}
EOF

        cat > index.js << 'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || ${API_PORT};

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        service: '${API_NAME}',
        environment: '${ENVIRONMENT}'
    });
});

// Welcome endpoint
app.get('/', (req, res) => {
    res.json({
        message: 'Welcome to ${API_NAME} API',
        version: '1.0.0',
        environment: '${ENVIRONMENT}',
        endpoints: {
            health: '/health',
            api: '/api'
        }
    });
});

// API routes
app.get('/api', (req, res) => {
    res.json({
        message: 'Hello from ${API_NAME}!',
        timestamp: new Date().toISOString()
    });
});

// Error handling
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ error: 'Something went wrong!' });
});

// 404 handler
app.use('*', (req, res) => {
    res.status(404).json({ error: 'Endpoint not found' });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`${API_NAME} API server running on port ${PORT}`);
});
EOF

        cat > .env << 'EOF'
NODE_ENV=${ENVIRONMENT}
PORT=${API_PORT}
API_NAME=${API_NAME}
EOF

        # Install dependencies
        sudo -u ec2-user npm install
        ;;

    "python")
        log "Creating Python application template..."
        cat > main.py << 'EOF'
#!/usr/bin/env python3
"""
${API_NAME} API Service
Created by Internal Developer Platform
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime
import uvicorn
import os

app = FastAPI(
    title="${API_NAME} API",
    description="API Service created by Internal Developer Platform",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "service": "${API_NAME}",
        "environment": "${ENVIRONMENT}"
    }

@app.get("/")
async def root():
    return {
        "message": "Welcome to ${API_NAME} API",
        "version": "1.0.0",
        "environment": "${ENVIRONMENT}",
        "docs": "/docs",
        "endpoints": {
            "health": "/health",
            "api": "/api"
        }
    }

@app.get("/api")
async def api_endpoint():
    return {
        "message": "Hello from ${API_NAME}!",
        "timestamp": datetime.now().isoformat()
    }

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=${API_PORT},
        reload=True if "${ENVIRONMENT}" == "dev" else False
    )
EOF

        cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
python-multipart==0.0.6
python-dotenv==1.0.0
EOF

        # Install dependencies
        sudo -u ec2-user python3 -m pip install -r requirements.txt
        ;;

    "java")
        log "Creating Java application template..."
        mkdir -p src/main/java/com/example/api
        
        cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.example</groupId>
    <artifactId>${API_NAME}</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>
    
    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <spring.boot.version>2.7.14</spring.boot.version>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
            <version>${spring.boot.version}</version>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <version>${spring.boot.version}</version>
            </plugin>
        </plugins>
    </build>
</project>
EOF

        # Build application
        sudo -u ec2-user mvn clean package -DskipTests
        ;;

    "go")
        log "Creating Go application template..."
        cat > main.go << 'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "time"
)

type HealthResponse struct {
    Status      string `json:"status"`
    Timestamp   string `json:"timestamp"`
    Service     string `json:"service"`
    Environment string `json:"environment"`
}

type APIResponse struct {
    Message   string `json:"message"`
    Timestamp string `json:"timestamp"`
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    response := HealthResponse{
        Status:      "healthy",
        Timestamp:   time.Now().Format(time.RFC3339),
        Service:     "${API_NAME}",
        Environment: "${ENVIRONMENT}",
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func apiHandler(w http.ResponseWriter, r *http.Request) {
    response := APIResponse{
        Message:   "Hello from ${API_NAME}!",
        Timestamp: time.Now().Format(time.RFC3339),
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func main() {
    http.HandleFunc("/health", healthHandler)
    http.HandleFunc("/api", apiHandler)
    
    port := "${API_PORT}"
    log.Printf("${API_NAME} API server starting on port %s", port)
    log.Fatal(http.ListenAndServe(fmt.Sprintf(":%s", port), nil))
}
EOF

        cat > go.mod << 'EOF'
module ${API_NAME}

go 1.21
EOF

        # Build application
        export PATH=$PATH:/usr/local/go/bin
        sudo -u ec2-user /usr/local/go/bin/go build -o ${API_NAME} main.go
        ;;
esac

# Create systemd service
log "Creating systemd service..."
case "$RUNTIME" in
    "nodejs")
        cat > /etc/systemd/system/${API_NAME}.service << 'EOF'
[Unit]
Description=${API_NAME} API Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/${API_NAME}
ExecStart=/usr/bin/node index.js
Restart=always
RestartSec=10
Environment=NODE_ENV=${ENVIRONMENT}
Environment=PORT=${API_PORT}

[Install]
WantedBy=multi-user.target
EOF
        ;;
    "python")
        cat > /etc/systemd/system/${API_NAME}.service << 'EOF'
[Unit]
Description=${API_NAME} API Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/${API_NAME}
ExecStart=/usr/bin/python3 main.py
Restart=always
RestartSec=10
Environment=ENVIRONMENT=${ENVIRONMENT}

[Install]
WantedBy=multi-user.target
EOF
        ;;
    "java")
        cat > /etc/systemd/system/${API_NAME}.service << 'EOF'
[Unit]
Description=${API_NAME} API Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/${API_NAME}
ExecStart=/usr/bin/java -jar target/${API_NAME}-1.0.0.jar
Restart=always
RestartSec=10
Environment=SERVER_PORT=${API_PORT}

[Install]
WantedBy=multi-user.target
EOF
        ;;
    "go")
        cat > /etc/systemd/system/${API_NAME}.service << 'EOF'
[Unit]
Description=${API_NAME} API Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/${API_NAME}
ExecStart=/opt/${API_NAME}/${API_NAME}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
        ;;
esac

# Set proper ownership
chown -R ec2-user:ec2-user /opt/$API_NAME

# Enable and start the service
systemctl daemon-reload
systemctl enable ${API_NAME}
systemctl start ${API_NAME}

# Configure nginx as reverse proxy
log "Configuring nginx reverse proxy..."
cat > /etc/nginx/conf.d/${API_NAME}.conf << 'EOF'
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:${API_PORT};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Start nginx
systemctl start nginx
systemctl enable nginx

# Create basic monitoring script
log "Setting up basic monitoring..."
cat > /opt/${API_NAME}/monitor.sh << 'EOF'
#!/bin/bash
# Basic health monitoring for ${API_NAME}

API_URL="http://localhost:${API_PORT}/health"
LOG_FILE="/var/log/${API_NAME}-monitor.log"

while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    if curl -f -s "$API_URL" > /dev/null; then
        echo "[$timestamp] API is healthy" >> "$LOG_FILE"
    else
        echo "[$timestamp] API health check failed" >> "$LOG_FILE"
        # Restart service if unhealthy
        systemctl restart ${API_NAME}
    fi
    sleep 60
done
EOF

chmod +x /opt/${API_NAME}/monitor.sh
chown ec2-user:ec2-user /opt/${API_NAME}/monitor.sh

# Create cron job for monitoring
echo "*/5 * * * * /opt/${API_NAME}/monitor.sh" | crontab -u ec2-user -

# Final status check
log "Performing final status check..."
sleep 30

if systemctl is-active --quiet ${API_NAME}; then
    log "✅ ${API_NAME} service is running successfully"
else
    log "❌ ${API_NAME} service failed to start"
    systemctl status ${API_NAME}
fi

if systemctl is-active --quiet nginx; then
    log "✅ Nginx is running successfully"
else
    log "❌ Nginx failed to start"
fi

# Test API endpoint
if curl -f -s "http://localhost:${API_PORT}/health" > /dev/null; then
    log "✅ API health check passed"
else
    log "❌ API health check failed"
fi

log "=== API Service Setup Complete ==="
log "API is available at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):${API_PORT}"
log "Health check: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):${API_PORT}/health"
log "Service logs: journalctl -f -u ${API_NAME}"
