"""
API Presentation Layer - FastAPI routes and controllers.

This layer handles HTTP requests, input validation, and response formatting.
It orchestrates use cases and transforms domain models for API responses.
"""

from typing import Dict, Any, List, Optional
from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel, Field

from ..application.use_cases import (
    CreateEC2RequestUseCase,
    CreateVPCRequestUseCase,
    CreateS3RequestUseCase,
    GetRequestStatusUseCase,
    ListRequestsUseCase,
    SubmitRequestUseCase,
    ProvisioningError
)
from ..domain.models import ResourceType, RequestStatus, ProvisioningRequest
from ..domain.interfaces import IProvisioningService
from ..infrastructure.queue_adapter import create_provisioning_service


# API Request/Response Models
class EC2RequestAPI(BaseModel):
    """API model for EC2 provisioning requests."""
    instance_type: str
    ami_id: str
    key_pair_name: str
    security_group_ids: List[str] = []
    subnet_id: Optional[str] = None
    user_data: Optional[str] = None
    tags: Dict[str, str] = {}


class VPCRequestAPI(BaseModel):
    """API model for VPC provisioning requests."""
    cidr_block: str
    enable_dns_hostnames: bool = True
    enable_dns_support: bool = True
    availability_zones: List[str] = []
    public_subnet_cidrs: List[str] = []
    private_subnet_cidrs: List[str] = []
    tags: Dict[str, str] = {}


class S3RequestAPI(BaseModel):
    """API model for S3 provisioning requests."""
    bucket_name: str
    versioning_enabled: bool = False
    encryption_enabled: bool = True
    public_read_access: bool = False
    lifecycle_rules: List[Dict[str, Any]] = []
    tags: Dict[str, str] = {}


class WebAppRequestAPI(BaseModel):
    """API model for web application template requests."""
    app_name: str = Field(..., description="Name of the web application")
    framework: str = Field(default="react", description="Frontend framework (react, vue, angular)")
    domain_name: str = Field(default="", description="Custom domain name (optional)")
    environment: str = Field(default="dev", description="Environment (dev, staging, prod)")
    database_required: bool = Field(default=True, description="Whether app needs a database")
    ssl_enabled: bool = Field(default=False, description="Enable SSL certificate")
    tags: Dict[str, str] = {}


class ApiServiceRequestAPI(BaseModel):
    """API model for API service template requests."""
    api_name: str = Field(..., description="Name of the API service")
    language: str = Field(default="nodejs", description="Programming language (nodejs, python, java, go)")
    database_required: bool = Field(default=True, description="Whether API needs a database")
    environment: str = Field(default="dev", description="Environment (dev, staging, prod)")
    auto_scaling: bool = Field(default=False, description="Enable auto scaling (increases cost)")
    tags: Dict[str, str] = {}


class GenericRequestAPI(BaseModel):
    """API model for generic provisioning requests."""
    resource_type: ResourceType
    resource_config: Dict[str, Any]


class RequestResponseAPI(BaseModel):
    """API response model for created requests."""
    request_id: str
    message: str


class StatusUpdateAPI(BaseModel):
    """API model for status updates (used by external processes)."""
    status: RequestStatus
    error_message: Optional[str] = None
    terraform_output: Optional[Dict[str, Any]] = None


# Dependency Injection
async def get_provisioning_service() -> IProvisioningService:
    """Dependency to provide provisioning service instance."""
    return create_provisioning_service()


# API Routes
def create_api() -> FastAPI:
    """Create and configure the FastAPI application."""
    
    app = FastAPI(
        title="Internal Developer Platform API",
        description="API for provisioning AWS resources and application templates",
        version="2.0.0"
    )
    
    @app.get("/")
    async def root():
        """Health check endpoint."""
        return {"message": "Internal Developer Platform API is running", "version": "2.0.0"}
    
    # Individual Resource Endpoints (Legacy)
    @app.post("/requests/ec2", response_model=RequestResponseAPI)
    async def create_ec2_request(
        request: EC2RequestAPI,
        requester: str = "ui-user",
        service: IProvisioningService = Depends(get_provisioning_service)
    ):
        """Create an EC2 provisioning request."""
        try:
            use_case = CreateEC2RequestUseCase(service)
            request_id = await use_case.execute(requester, request.model_dump())
            return RequestResponseAPI(
                request_id=request_id,
                message=f"EC2 instance request created successfully"
            )
        except ProvisioningError as e:
            raise HTTPException(status_code=400, detail=str(e))
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

    @app.post("/requests/vpc", response_model=RequestResponseAPI)
    async def create_vpc_request(
        request: VPCRequestAPI,
        requester: str = "ui-user",
        service: IProvisioningService = Depends(get_provisioning_service)
    ):
        """Create a VPC provisioning request."""
        try:
            use_case = CreateVPCRequestUseCase(service)
            request_id = await use_case.execute(requester, request.model_dump())
            return RequestResponseAPI(
                request_id=request_id,
                message=f"VPC network request created successfully"
            )
        except ProvisioningError as e:
            raise HTTPException(status_code=400, detail=str(e))
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

    @app.post("/requests/s3", response_model=RequestResponseAPI)
    async def create_s3_request(
        request: S3RequestAPI,
        requester: str = "ui-user",
        service: IProvisioningService = Depends(get_provisioning_service)
    ):
        """Create an S3 bucket provisioning request."""
        try:
            use_case = CreateS3RequestUseCase(service)
            request_id = await use_case.execute(requester, request.model_dump())
            return RequestResponseAPI(
                request_id=request_id,
                message=f"S3 bucket '{request.bucket_name}' request created successfully"
            )
        except ProvisioningError as e:
            raise HTTPException(status_code=400, detail=str(e))
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

    # Application Template Endpoints (New)
    @app.post("/requests/web-app", response_model=RequestResponseAPI)
    async def create_web_app_request(
        request: WebAppRequestAPI,
        requester: str = "ui-user",
        service: IProvisioningService = Depends(get_provisioning_service)
    ):
        """Create a complete web application stack."""
        try:
            use_case = SubmitRequestUseCase(service)
            request_id = await use_case.execute(requester, ResourceType.WEB_APP, request.model_dump())
            return RequestResponseAPI(
                request_id=request_id,
                message=f"Web application '{request.app_name}' stack request created successfully"
            )
        except ProvisioningError as e:
            raise HTTPException(status_code=400, detail=str(e))
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

    @app.post("/requests/api-service", response_model=RequestResponseAPI)
    async def create_api_service_request(
        request: ApiServiceRequestAPI,
        requester: str = "ui-user",
        service: IProvisioningService = Depends(get_provisioning_service)
    ):
        """Create a simple API service with optional database."""
        try:
            use_case = SubmitRequestUseCase(service)
            request_id = await use_case.execute(requester, ResourceType.API_SERVICE, request.model_dump())
            return RequestResponseAPI(
                request_id=request_id,
                message=f"API service '{request.api_name}' request created successfully"
            )
        except ProvisioningError as e:
            raise HTTPException(status_code=400, detail=str(e))
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

    # Generic endpoint for any request type
    @app.post("/requests", response_model=RequestResponseAPI)
    async def create_generic_request(
        request: GenericRequestAPI,
        requester: str = "ui-user",
        service: IProvisioningService = Depends(get_provisioning_service)
    ):
        """Create a generic provisioning request."""
        try:
            use_case = SubmitRequestUseCase(service)
            request_id = await use_case.execute(
                requester, 
                request.resource_type, 
                request.resource_config
            )
            return RequestResponseAPI(
                request_id=request_id,
                message=f"{request.resource_type.value} request created successfully"
            )
        except ProvisioningError as e:
            raise HTTPException(status_code=400, detail=str(e))
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

    # Request management endpoints
    @app.get("/requests")
    async def list_requests(
        requester: Optional[str] = None,
        service: IProvisioningService = Depends(get_provisioning_service)
    ):
        """List all provisioning requests, optionally filtered by requester."""
        try:
            use_case = ListRequestsUseCase(service)
            requests = await use_case.execute(requester)
            return [req.model_dump() for req in requests]
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

    @app.get("/requests/{request_id}")
    async def get_request_status(
        request_id: str,
        service: IProvisioningService = Depends(get_provisioning_service)
    ):
        """Get the status of a specific provisioning request."""
        try:
            use_case = GetRequestStatusUseCase(service)
            request = await use_case.execute(request_id)
            if not request:
                raise HTTPException(status_code=404, detail="Request not found")
            return request.model_dump()
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

    @app.patch("/requests/{request_id}/status")
    async def update_request_status(
        request_id: str,
        status_update: StatusUpdateAPI,
        service: IProvisioningService = Depends(get_provisioning_service)
    ):
        """Update the status of a provisioning request (used by external processing scripts)."""
        try:
            success = await service.update_request_status(request_id, status_update.model_dump())
            if not success:
                raise HTTPException(status_code=404, detail="Request not found")
            return {"message": "Status updated successfully"}
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

    return app
