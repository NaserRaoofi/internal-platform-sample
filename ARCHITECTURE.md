# Clean Architecture Implementation Guide

## Overview

This Internal Developer Platform implements **Clean Architecture** principles to maintain separation of concerns, testability, and maintainability. The architecture ensures that business logic is independent of frameworks, databases, and external services.

## Architecture Layers

### 1. Domain Layer (`backend/domain/`)

**Purpose**: Contains the core business logic and entities that are independent of any external concerns.

**Components**:
- `models.py`: Core business entities and value objects
- `interfaces.py`: Abstract contracts using `@abstractmethod`

**Key Principles**:
- No dependencies on external frameworks
- Contains pure business logic
- Defines contracts for external services

**Example**:
```python
# Domain models are framework-agnostic
class ProvisioningRequest(BaseModel):
    id: str
    requester: str
    resource_type: ResourceType
    status: RequestStatus
    
    def mark_completed(self):  # Business logic
        self.status = RequestStatus.COMPLETED
        self.updated_at = datetime.utcnow()
```

### 2. Application Layer (`backend/application/`)

**Purpose**: Orchestrates business workflows and coordinates between domain and infrastructure layers.

**Components**:
- `use_cases.py`: Application-specific business rules and workflows

**Key Principles**:
- Depends only on domain interfaces
- Implements application-specific business rules
- Coordinates domain objects

**Example**:
```python
class CreateEC2RequestUseCase:
    def __init__(self, provisioning_service: IProvisioningService):
        self.provisioning_service = provisioning_service  # Depends on interface
    
    async def execute(self, requester: str, config: Dict) -> str:
        # Application logic: validate, create, submit
        ec2_request = EC2Request(**config)  # Domain validation
        request = ProvisioningRequest(...)   # Domain entity
        return await self.provisioning_service.submit_request(request)
```

### 3. Infrastructure Layer (`backend/infrastructure/`)

**Purpose**: Implements domain interfaces and handles external concerns like file I/O, databases, and third-party services.

**Components**:
- `queue_adapter.py`: Concrete implementations of domain interfaces

**Key Principles**:
- Implements domain interfaces
- Handles external dependencies
- Isolated from business logic

**Example**:
```python
class FileBasedRequestQueue(IRequestQueue):  # Implements domain interface
    async def enqueue(self, request: ProvisioningRequest) -> bool:
        # Infrastructure concern: file system operations
        file_path = self.pending_dir / f"{request.id}.json"
        with open(file_path, 'w') as f:
            json.dump(request.model_dump(), f)
```

### 4. Presentation Layer (`backend/presentation/`)

**Purpose**: Handles HTTP requests, input validation, and response formatting.

**Components**:
- `api.py`: FastAPI routes and controllers

**Key Principles**:
- Depends on application use cases
- Handles HTTP concerns
- Transforms between API and domain models

**Example**:
```python
@app.post("/requests/ec2")
async def create_ec2_request(
    request: EC2RequestAPI,  # API model
    service: IProvisioningService = Depends(get_provisioning_service)
):
    use_case = CreateEC2RequestUseCase(service)  # Application layer
    request_id = await use_case.execute(requester, request.model_dump())
    return RequestResponseAPI(request_id=request_id)  # API response
```

## The `@abstractmethod` Decorator

### What is `@abstractmethod`?

The `@abstractmethod` decorator is Python's way of defining abstract methods that **must** be implemented by concrete subclasses.

### How it Works:

```python
from abc import ABC, abstractmethod

class IProvisioningService(ABC):  # Abstract Base Class
    @abstractmethod
    async def submit_request(self, request: ProvisioningRequest) -> str:
        """This method MUST be implemented by subclasses."""
        pass

# This will work:
class ConcreteService(IProvisioningService):
    async def submit_request(self, request: ProvisioningRequest) -> str:
        # Implementation here
        return request.id

# This will raise TypeError when instantiated:
class IncompleteService(IProvisioningService):
    pass  # Missing submit_request implementation

# TypeError: Can't instantiate abstract class IncompleteService 
# with abstract method submit_request
service = IncompleteService()  # ❌ This fails
```

### Benefits:

1. **Contract Enforcement**: Ensures all implementations provide required methods
2. **Compile-time Checking**: Catches missing implementations early
3. **Documentation**: Clearly defines what methods must be implemented
4. **IDE Support**: Provides better autocomplete and error checking

### In This Project:

```python
# Domain defines the contract
class IProvisioningService(ABC):
    @abstractmethod
    async def submit_request(self, request: ProvisioningRequest) -> str:
        pass

# Infrastructure implements the contract
class QueueProvisioningService(IProvisioningService):
    async def submit_request(self, request: ProvisioningRequest) -> str:
        # File-based implementation
        await self.repository.save(request)
        return await self.queue.enqueue(request)

# Application uses the interface
class CreateEC2RequestUseCase:
    def __init__(self, service: IProvisioningService):  # Depends on interface
        self.service = service
```

## Dependency Flow

```
Presentation Layer (FastAPI)
    ↓ depends on
Application Layer (Use Cases)
    ↓ depends on
Domain Layer (Interfaces + Models)
    ↑ implemented by
Infrastructure Layer (Concrete Implementations)
```

### Key Rules:

1. **Inner layers never depend on outer layers**
2. **Dependencies point inward toward domain**
3. **Infrastructure implements domain interfaces**
4. **Presentation uses application use cases**

## Benefits of This Architecture

### 1. **Testability**
```python
# Easy to test with mocks
class MockProvisioningService(IProvisioningService):
    async def submit_request(self, request):
        return "mock-id"

# Test the use case with mock
use_case = CreateEC2RequestUseCase(MockProvisioningService())
```

### 2. **Flexibility**
```python
# Easy to swap implementations
def create_service():
    if config.USE_DATABASE:
        return DatabaseProvisioningService()
    else:
        return FileBasedProvisioningService()
```

### 3. **Independence**
- Business logic doesn't depend on FastAPI, file systems, or databases
- Can change from files to Redis without touching business logic
- Can change from FastAPI to Flask without changing domain

### 4. **Maintainability**
- Clear separation of concerns
- Each layer has a single responsibility
- Easy to locate and modify specific functionality

## External Processing (Terraform)

The architecture keeps Terraform execution **external** to maintain the separation:

```
UI → API → Queue → External Script → Terraform
                      ↓
                  Status Update → API → Storage
```

### Why External?

1. **Clean Architecture**: Infrastructure provisioning is not core business logic
2. **Scalability**: Can run in separate processes/containers
3. **Reliability**: Failures don't crash the main application
4. **Flexibility**: Can use CI/CD, cron jobs, or message queues

## Example Request Flow

1. **UI** submits EC2 request → **Presentation Layer**
2. **API** validates input → **Application Layer** 
3. **Use Case** creates domain objects → **Domain Layer**
4. **Service** writes to queue → **Infrastructure Layer**
5. **External Script** reads queue → **Terraform**
6. **Script** updates status → **Infrastructure Layer**
7. **API** returns status → **Presentation Layer**

This flow demonstrates how each layer has a clear responsibility while maintaining loose coupling through interfaces.
