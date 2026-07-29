# Guide: Deploying FID Attendance System to VPS with Docker

This guide explains how to deploy the FID Attendance System to your VPS (Ubuntu/Debian) using Docker and Docker Compose.

---

## 1. Prerequisites on VPS
Ensure Docker and Docker Compose are installed on your VPS:
```bash
# Update package list & install Docker
sudo apt update && sudo apt install -y docker.io docker-compose-plugin git
sudo systemctl enable --now docker
```

---

## 2. Clone the Repository
Clone the project repository to your VPS:
```bash
git clone https://github.com/ricojoid/fid-attendance.git
cd fid-attendance
```

---

## 3. Deployment Options

### Option A: PostgreSQL Mode (Recommended for Production)
Runs **PostgreSQL + Go Backend + React Frontend (Nginx)**:
```bash
docker compose up -d --build
```

### Option B: SQLite Mode (Lightweight / Low Resource VPS)
Runs **Go Backend (Embedded SQLite) + React Frontend (Nginx)**:
```bash
docker compose -f docker-compose.sqlite.yml up -d --build
```

---

## 4. Check Container Status
Verify that all containers are healthy and running:
```bash
docker compose ps
docker compose logs -f backend
```

Access points:
- **Web Frontend (Admin & User Dashboard)**: `http://YOUR_VPS_IP`
- **Backend REST API**: `http://YOUR_VPS_IP:8080/api`

---

## 5. (Optional) Mobile App Base URL Configuration
In your Flutter mobile app (`mobile/lib/services/api_service.dart`), update `baseUrl` to point to your VPS IP or Domain:
```dart
static const String baseUrl = 'http://YOUR_VPS_IP/api';
```

---

## 6. (Optional) Enable HTTPS / SSL with Domain
If you have a domain pointing to your VPS IP (e.g. `attendance.yourdomain.com`):
```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d attendance.yourdomain.com
```

---

## 7. Management Commands
- **Stop services**: `docker compose down`
- **View real-time logs**: `docker compose logs -f`
- **Rebuild after pulling new updates**:
  ```bash
  git pull
  docker compose up -d --build
  ```
