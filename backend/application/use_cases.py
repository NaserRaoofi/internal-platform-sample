"""
Application Use Cases - Business logic and orchestration.

This layer contains the application-specific business rules and orchestrates
the flow between domain objects and infrastructure services.

Updated to support real-world application templates instead of individual resources.
"""

import uuid
from typing import Dict, Any, List, Optional
from datetime import datetime

from ..domain.models import (
    ProvisioningRequest, 
    WebAppRequest,
    ApiServiceRequest,
    ResourceType,
    RequestStatus
)
from ..domain.interfaces import IProvisioningService


class ProvisioningError(Exception):
    """Custom exception for provisioning-related errors."""
    pass


class CreateWebAppRequestUseCase:
    """Use case for creating web application provisioning requests."""
    
    def __init__(self, provisioning_service: IProvisioningService):
        self.provisioning_service = provisioning_service
    
    async def execute(self, requester: str, webapp_config: Dict[str, Any]) -> str:
        """
        Create and submit a web application provisioning request.
        
        Args:
            requester: Username of the person making the request
            webapp_config: Web application configuration parameters
            
        Returns:
            str: The unique request ID
            
        Raises:
            ProvisioningError: If validation or submission fails
        """
        try:
            # Validate web app configuration
            webapp_request = WebAppRequest(**webapp_config)
            
            # Create provisioning request
            request = ProvisioningRequest(
                id=str(uuid.uuid4()),
                requester=requester,
                resource_type=ResourceType.WEB_APP,
                resource_config=webapp_request.model_dump(),
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
            raise ProvisioningError(f"Failed to create web app request: {str(e)}")


class CreateApiServiceRequestUseCase:
    """Use case for creating API service provisioning requests."""
    
    def __init__(self, provisioning_service: IProvisioningService):
        self.provisioning_service = provisioning_service
    
    async def execute(self, requester: str, api_config: Dict[str, Any]) -> str:
        """
        Create and submit an API service provisioning request.
        
        Args:
            requester: Username of the person making the request
            api_config: API service configuration parameters
            
        Returns:
            str: The unique request ID
        """
        try:
            # Validate API service configuration
            api_request = ApiServiceRequest(**api_config)
            
            # Create provisioning request
            request = ProvisioningRequest(
                id=str(uuid.uuid4()),
                requester=requester,
                resource_type=ResourceType.API_SERVICE,
                resource_config=api_request.model_dump(),
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
            raise ProvisioningError(f"Failed to create API service request: {str(e)}")


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
            if resource_type == ResourceType.WEB_APP:
                validated_config = WebAppRequest(**resource_config).model_dump()
            elif resource_type == ResourceType.API_SERVICE:
                validated_config = ApiServiceRequest(**resource_config).model_dump()
            elif resource_type == ResourceType.DATA_PIPELINE:
                # For future data pipeline support
                validated_config = resource_config
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


class ApproveRequestUseCase:
    """Use case for approving provisioning requests."""
    
    def __init__(self, provisioning_service: IProvisioningService):
        self.provisioning_service = provisioning_service
    
    async def execute(self, request_id: str, approver: str) -> bool:
        """
        Approve a provisioning request.
        
        Args:
            request_id: The unique identifier of the request to approve
            approver: Username of the person approving the request
            
        Returns:
            bool: True if approval was successful
        """
        try:
            return await self.provisioning_service.approve_request(request_id, approver)
        except Exception as e:
            raise ProvisioningError(f"Failed to approve request: {str(e)}")


class RejectRequestUseCase:
    """Use case for rejecting provisioning requests."""
    
    def __init__(self, provisioning_service: IProvisioningService):
        self.provisioning_service = provisioning_service
    
    async def execute(self, request_id: str, approver: str, reason: str = "") -> bool:
        """
        Reject a provisioning request.
        
        Args:
            request_id: The unique identifier of the request to reject
            approver: Username of the person rejecting the request
            reason: Optional reason for rejection
            
        Returns:
            bool: True if rejection was successful
        """
        try:
            return await self.provisioning_service.reject_request(request_id, approver, reason)
        except Exception as e:
            raise ProvisioningError(f"Failed to reject request: {str(e)}")
