# Internal Developer Platform

A Clean Architecture-based platform for provisioning AWS resources (EC2, VPC, S3) via a simple UI.

## Architecture Overview

- **Frontend**: Flet UI for collecting user input
- **Backend**: FastAPI with Clean Architecture
- **Infrastructure**: Terraform modules managed independently
- **Job Processing**: External scripts for Terraform execution

## Project Structure

```
.
├── backend/           # Clean Architecture API
├── ui/               # Flet frontend
├── terraform/        # Infrastructure modules
├── scripts/          # Terraform execution scripts
└── queue/            # Request queue (file-based)
```

## Quick Start

1. Install dependencies:
```bash
poetry install
```

2. Start the backend:
```bash
cd backend && poetry run uvicorn main:app --reload
```

3. Start the UI:
```bash
cd ui && poetry run python app.py
```

4. Process requests:
```bash
./scripts/apply.sh
```

## Logic Flow

1. Developer submits request via UI
2. Backend validates and queues request (JSON file)
3. External process reads queue and applies Terraform
4. Status updates are written back

## Clean Architecture Layers

- **Domain**: Business models and interfaces
- **Application**: Use cases and business logic
- **Infrastructure**: External services and adapters
- **Presentation**: API routes and controllers
