#!/bin/bash
# API Server Setup Script for Web App Simple Template
# This script sets up the backend API server based on the selected runtime

set -e

# Variables from Terraform
APP_NAME="${app_name}"
ENVIRONMENT="${environment}"
API_PORT="${api_port}"
RUNTIME="${runtime}"
DATABASE_REQUIRED="${database_required}"
DATABASE_ENDPOINT="${database_endpoint}"
DATABASE_NAME="${database_name}"
DATABASE_USERNAME="${database_username}"
S3_BUCKET="${s3_bucket}"

# System updates and basic tools
yum update -y
yum install -y wget curl unzip git htop

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Setup application directory
mkdir -p /opt/$APP_NAME
cd /opt/$APP_NAME

# Create systemd service file
cat > /etc/systemd/system/$APP_NAME.service << EOF
[Unit]
Description=$APP_NAME API Server
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/$APP_NAME
Environment=NODE_ENV=$ENVIRONMENT
Environment=API_PORT=$API_PORT
Environment=APP_NAME=$APP_NAME
Environment=S3_BUCKET=$S3_BUCKET
$(if [ "$DATABASE_REQUIRED" = "true" ]; then
cat << EOL
Environment=DATABASE_HOST=$DATABASE_ENDPOINT
Environment=DATABASE_NAME=$DATABASE_NAME
Environment=DATABASE_USER=$DATABASE_USERNAME
EOL
fi)
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Runtime-specific setup
case $RUNTIME in
  "nodejs")
    # Install Node.js 18
    curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
    yum install -y nodejs

    # Create sample Node.js application
    cat > /opt/$APP_NAME/package.json << 'EOF'
{
  "name": "web-app-api",
  "version": "1.0.0",
  "description": "Simple API server for web application",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

    cat > /opt/$APP_NAME/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
require('dotenv').config();

const app = express();
const PORT = process.env.API_PORT || 8080;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    app: process.env.APP_NAME || 'web-app',
    environment: process.env.NODE_ENV || 'development'
  });
});

// API routes
app.get('/api/status', (req, res) => {
  res.json({ 
    message: 'API is running',
    version: '1.0.0',
    environment: process.env.NODE_ENV
  });
});

app.get('/api/info', (req, res) => {
  res.json({
    app_name: process.env.APP_NAME,
    s3_bucket: process.env.S3_BUCKET,
    database_connected: process.env.DATABASE_HOST ? true : false
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV}`);
  console.log(`App: ${process.env.APP_NAME}`);
});
EOF

    # Install dependencies
    cd /opt/$APP_NAME
    npm install

    # Update systemd service for Node.js
    sed -i 's|ExecStart=.*|ExecStart=/usr/bin/node server.js|' /etc/systemd/system/$APP_NAME.service
    ;;

  "python")
    # Install Python 3.9 and pip
    yum install -y python3 python3-pip

    # Create sample Python Flask application
    cat > /opt/$APP_NAME/requirements.txt << 'EOF'
Flask==2.3.3
Flask-CORS==4.0.0
gunicorn==21.2.0
python-dotenv==1.0.0
EOF

    cat > /opt/$APP_NAME/app.py << 'EOF'
from flask import Flask, jsonify
from flask_cors import CORS
import os
from datetime import datetime

app = Flask(__name__)
CORS(app)

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'app': os.getenv('APP_NAME', 'web-app'),
        'environment': os.getenv('FLASK_ENV', 'development')
    })

@app.route('/api/status')
def status():
    return jsonify({
        'message': 'API is running',
        'version': '1.0.0',
        'environment': os.getenv('FLASK_ENV')
    })

@app.route('/api/info')
def info():
    return jsonify({
        'app_name': os.getenv('APP_NAME'),
        's3_bucket': os.getenv('S3_BUCKET'),
        'database_connected': bool(os.getenv('DATABASE_HOST'))
    })

if __name__ == '__main__':
    port = int(os.getenv('API_PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
EOF

    # Install dependencies
    cd /opt/$APP_NAME
    pip3 install -r requirements.txt

    # Update systemd service for Python
    sed -i 's|ExecStart=.*|ExecStart=/usr/bin/python3 app.py|' /etc/systemd/system/$APP_NAME.service
    ;;

  "go")
    # Install Go
    wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
    tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    export PATH=$PATH:/usr/local/go/bin

    # Create sample Go application
    cat > /opt/$APP_NAME/main.go << 'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
    "time"
)

type HealthResponse struct {
    Status      string `json:"status"`
    Timestamp   string `json:"timestamp"`
    App         string `json:"app"`
    Environment string `json:"environment"`
}

type StatusResponse struct {
    Message     string `json:"message"`
    Version     string `json:"version"`
    Environment string `json:"environment"`
}

type InfoResponse struct {
    AppName           string `json:"app_name"`
    S3Bucket          string `json:"s3_bucket"`
    DatabaseConnected bool   `json:"database_connected"`
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    response := HealthResponse{
        Status:      "healthy",
        Timestamp:   time.Now().Format(time.RFC3339),
        App:         getEnv("APP_NAME", "web-app"),
        Environment: getEnv("GO_ENV", "development"),
    }
    json.NewEncoder(w).Encode(response)
}

func statusHandler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    response := StatusResponse{
        Message:     "API is running",
        Version:     "1.0.0",
        Environment: getEnv("GO_ENV", "development"),
    }
    json.NewEncoder(w).Encode(response)
}

func infoHandler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    response := InfoResponse{
        AppName:           getEnv("APP_NAME", ""),
        S3Bucket:          getEnv("S3_BUCKET", ""),
        DatabaseConnected: getEnv("DATABASE_HOST", "") != "",
    }
    json.NewEncoder(w).Encode(response)
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func main() {
    port := getEnv("API_PORT", "8080")
    
    http.HandleFunc("/health", healthHandler)
    http.HandleFunc("/api/status", statusHandler)
    http.HandleFunc("/api/info", infoHandler)
    
    fmt.Printf("Server starting on port %s\n", port)
    fmt.Printf("Environment: %s\n", getEnv("GO_ENV", "development"))
    fmt.Printf("App: %s\n", getEnv("APP_NAME", "web-app"))
    
    log.Fatal(http.ListenAndServe(":"+port, nil))
}
EOF

    # Build the application
    cd /opt/$APP_NAME
    /usr/local/go/bin/go mod init web-app-api
    /usr/local/go/bin/go build -o server main.go

    # Update systemd service for Go
    sed -i 's|ExecStart=.*|ExecStart=/opt/'$APP_NAME'/server|' /etc/systemd/system/$APP_NAME.service
    ;;

  "java")
    # Install Java 11
    yum install -y java-11-amazon-corretto

    # Create sample Java Spring Boot application (simplified)
    mkdir -p /opt/$APP_NAME/src/main/java/com/example/webapp
    
    cat > /opt/$APP_NAME/WebApp.java << 'EOF'
import java.io.*;
import java.net.*;
import java.util.*;
import java.text.SimpleDateFormat;

public class WebApp {
    private static final int PORT = Integer.parseInt(System.getenv().getOrDefault("API_PORT", "8080"));
    
    public static void main(String[] args) throws IOException {
        ServerSocket serverSocket = new ServerSocket(PORT);
        System.out.println("Server starting on port " + PORT);
        System.out.println("Environment: " + System.getenv().getOrDefault("JAVA_ENV", "development"));
        System.out.println("App: " + System.getenv().getOrDefault("APP_NAME", "web-app"));
        
        while (true) {
            Socket clientSocket = serverSocket.accept();
            new Thread(() -> handleRequest(clientSocket)).start();
        }
    }
    
    private static void handleRequest(Socket clientSocket) {
        try {
            BufferedReader in = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));
            PrintWriter out = new PrintWriter(clientSocket.getOutputStream(), true);
            
            String inputLine = in.readLine();
            if (inputLine != null && inputLine.startsWith("GET")) {
                String path = inputLine.split(" ")[1];
                String response = getResponse(path);
                
                out.println("HTTP/1.1 200 OK");
                out.println("Content-Type: application/json");
                out.println("Access-Control-Allow-Origin: *");
                out.println();
                out.println(response);
            }
            
            clientSocket.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
    
    private static String getResponse(String path) {
        SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
        String timestamp = sdf.format(new Date());
        
        switch (path) {
            case "/health":
                return String.format("{\"status\":\"healthy\",\"timestamp\":\"%s\",\"app\":\"%s\",\"environment\":\"%s\"}", 
                    timestamp, 
                    System.getenv().getOrDefault("APP_NAME", "web-app"),
                    System.getenv().getOrDefault("JAVA_ENV", "development"));
            case "/api/status":
                return String.format("{\"message\":\"API is running\",\"version\":\"1.0.0\",\"environment\":\"%s\"}", 
                    System.getenv().getOrDefault("JAVA_ENV", "development"));
            case "/api/info":
                return String.format("{\"app_name\":\"%s\",\"s3_bucket\":\"%s\",\"database_connected\":%s}", 
                    System.getenv().getOrDefault("APP_NAME", ""),
                    System.getenv().getOrDefault("S3_BUCKET", ""),
                    System.getenv("DATABASE_HOST") != null ? "true" : "false");
            default:
                return "{\"error\":\"Not found\"}";
        }
    }
}
EOF

    # Compile the Java application
    cd /opt/$APP_NAME
    javac WebApp.java

    # Update systemd service for Java
    sed -i 's|ExecStart=.*|ExecStart=/usr/bin/java WebApp|' /etc/systemd/system/$APP_NAME.service
    ;;

esac

# Set ownership
chown -R ec2-user:ec2-user /opt/$APP_NAME

# Install and configure nginx as reverse proxy
yum install -y nginx

cat > /etc/nginx/conf.d/$APP_NAME.conf << EOF
server {
    listen 80;
    server_name _;

    # Health check endpoint (direct)
    location /health {
        proxy_pass http://localhost:$API_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # API endpoints
    location /api/ {
        proxy_pass http://localhost:$API_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Default response for other requests
    location / {
        return 200 '{"message":"API Server is running","app":"$APP_NAME","environment":"$ENVIRONMENT"}';
        add_header Content-Type application/json;
    }
}
EOF

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/nginx/access.log",
                        "log_group_name": "/aws/ec2/$APP_NAME/nginx",
                        "log_stream_name": "access.log"
                    },
                    {
                        "file_path": "/var/log/nginx/error.log",
                        "log_group_name": "/aws/ec2/$APP_NAME/nginx",
                        "log_stream_name": "error.log"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "WebApp/$APP_NAME",
        "metrics_collected": {
            "cpu": {
                "measurement": ["cpu_usage_idle", "cpu_usage_iowait"],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": ["used_percent"],
                "metrics_collection_interval": 60,
                "resources": ["*"]
            },
            "mem": {
                "measurement": ["mem_used_percent"],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Enable and start services
systemctl daemon-reload
systemctl enable nginx
systemctl enable $APP_NAME
systemctl enable amazon-cloudwatch-agent

systemctl start nginx
systemctl start $APP_NAME
systemctl start amazon-cloudwatch-agent

# Create a simple status script
cat > /opt/$APP_NAME/status.sh << 'EOF'
#!/bin/bash
echo "=== Application Status ==="
echo "Service Status:"
systemctl is-active $APP_NAME
echo ""
echo "Port Check:"
netstat -tlnp | grep :$API_PORT
echo ""
echo "Recent Logs:"
journalctl -u $APP_NAME --no-pager -n 10
EOF

chmod +x /opt/$APP_NAME/status.sh

echo "Setup complete! API server should be running on port $API_PORT"
echo "Check status with: sudo /opt/$APP_NAME/status.sh"
