"""
Application Use Cases - Business logic and orchestration.

This layer contains the application-specific business rules and orchestrates
the flow between domain objects and infrastructure services.
"""

import uuid
from typing import Dict, Any, List, Optional
from datetime import datetime

from ..domain.models import (
    ProvisioningRequest, 
    EC2Request, 
    VPCRequest, 
    S3Request, 
    ResourceType,
    RequestStatus
)
from ..domain.interfaces import IProvisioningService


class ProvisioningError(Exception):
    """Custom exception for provisioning-related errors."""
    pass


class CreateEC2RequestUseCase:
    """Use case for creating EC2 provisioning requests."""
    
    def __init__(self, provisioning_service: IProvisioningService):
        self.provisioning_service = provisioning_service
    
    async def execute(self, requester: str, ec2_config: Dict[str, Any]) -> str:
        """
        Create and submit an EC2 provisioning request.
        
        Args:
            requester: Username of the person making the request
            ec2_config: EC2 configuration parameters
            
        Returns:
            str: The unique request ID
            
        Raises:
            ProvisioningError: If validation or submission fails
        """
        try:
            # Validate EC2 configuration
            ec2_request = EC2Request(**ec2_config)
            
            # Create provisioning request
            request = ProvisioningRequest(
                id=str(uuid.uuid4()),
                requester=requester,
                resource_type=ResourceType.EC2,
                resource_config=ec2_request.model_dump(),
                status=RequestStatus.PENDING,
                created_at=datetime.utcnow(),
                updated_at=None,
                error_message=None,
                terraform_output=None
            )
            
            # Submit to provisioning service
            request_id = await self.provisioning_service.submit_request(request)
            return request_id
            
        except Exception as e:
            raise ProvisioningError(f"Failed to create EC2 request: {str(e)}")


class CreateVPCRequestUseCase:
    """Use case for creating VPC provisioning requests."""
    
    def __init__(self, provisioning_service: IProvisioningService):
        self.provisioning_service = provisioning_service
    
    async def execute(self, requester: str, vpc_config: Dict[str, Any]) -> str:
        """
        Create and submit a VPC provisioning request.
        
        Args:
            requester: Username of the person making the request
            vpc_config: VPC configuration parameters
            
        Returns:
            str: The unique request ID
        """
        try:
            # Validate VPC configuration
            vpc_request = VPCRequest(**vpc_config)
            
            # Create provisioning request
            request = ProvisioningRequest(
                id=str(uuid.uuid4()),
                requester=requester,
                resource_type=ResourceType.VPC,
                resource_config=vpc_request.model_dump(),
                status=RequestStatus.PENDING,
                created_at=datetime.utcnow(),
                updated_at=None,
                error_message=None,
                terraform_output=None
            )
            
            # Submit to provisioning service
            request_id = await self.provisioning_service.submit_request(request)
            return request_id
            
        except Exception as e:
            raise ProvisioningError(f"Failed to create VPC request: {str(e)}")


class CreateS3RequestUseCase:
    """Use case for creating S3 provisioning requests."""
    
    def __init__(self, provisioning_service: IProvisioningService):
        self.provisioning_service = provisioning_service
    
    async def execute(self, requester: str, s3_config: Dict[str, Any]) -> str:
        """
        Create and submit an S3 provisioning request.
        
        Args:
            requester: Username of the person making the request
            s3_config: S3 configuration parameters
            
        Returns:
            str: The unique request ID
        """
        try:
            # Validate S3 configuration
            s3_request = S3Request(**s3_config)
            
            # Create provisioning request
            request = ProvisioningRequest(
                id=str(uuid.uuid4()),
                requester=requester,
                resource_type=ResourceType.S3,
                resource_config=s3_request.model_dump(),
                status=RequestStatus.PENDING,
                created_at=datetime.utcnow(),
                updated_at=None,
                error_message=None,
                terraform_output=None
            )
            
            # Submit to provisioning service
            request_id = await self.provisioning_service.submit_request(request)
            return request_id
            
        except Exception as e:
            raise ProvisioningError(f"Failed to create S3 request: {str(e)}")


class GetRequestStatusUseCase:
    """Use case for retrieving request status."""
    
    def __init__(self, provisioning_service: IProvisioningService):
        self.provisioning_service = provisioning_service
    
    async def execute(self, request_id: str) -> Optional[ProvisioningRequest]:
        """
        Get the current status of a provisioning request.
        
        Args:
            request_id: The unique identifier of the request
            
        Returns:
            ProvisioningRequest: The request with current status, or None if not found
        """
        return await self.provisioning_service.get_request_status(request_id)


class ListRequestsUseCase:
    """Use case for listing provisioning requests."""
    
    def __init__(self, provisioning_service: IProvisioningService):
        self.provisioning_service = provisioning_service
    
    async def execute(self, requester: Optional[str] = None) -> List[ProvisioningRequest]:
        """
        List provisioning requests, optionally filtered by requester.
        
        Args:
            requester: Optional username to filter requests
            
        Returns:
            List[ProvisioningRequest]: List of matching requests
        """
        return await self.provisioning_service.list_requests(requester)


class SubmitRequestUseCase:
    """Generic use case for submitting any type of provisioning request."""
    
    def __init__(self, provisioning_service: IProvisioningService):
        self.provisioning_service = provisioning_service
    
    async def execute(
        self, 
        requester: str, 
        resource_type: ResourceType, 
        resource_config: Dict[str, Any]
    ) -> str:
        """
        Submit a generic provisioning request.
        
        Args:
            requester: Username of the person making the request
            resource_type: Type of resource to provision
            resource_config: Resource-specific configuration
            
        Returns:
            str: The unique request ID
        """
        try:
            # Validate configuration based on resource type
            if resource_type == ResourceType.EC2:
                validated_config = EC2Request(**resource_config).model_dump()
            elif resource_type == ResourceType.VPC:
                validated_config = VPCRequest(**resource_config).model_dump()
            elif resource_type == ResourceType.S3:
                validated_config = S3Request(**resource_config).model_dump()
            else:
                raise ProvisioningError(f"Unsupported resource type: {resource_type}")
            
            # Create provisioning request
            request = ProvisioningRequest(
                id=str(uuid.uuid4()),
                requester=requester,
                resource_type=resource_type,
                resource_config=validated_config,
                status=RequestStatus.PENDING,
                created_at=datetime.utcnow(),
                updated_at=None,
                error_message=None,
                terraform_output=None
            )
            
            # Submit to provisioning service
            request_id = await self.provisioning_service.submit_request(request)
            return request_id
            
        except Exception as e:
            raise ProvisioningError(f"Failed to submit {resource_type} request: {str(e)}")
