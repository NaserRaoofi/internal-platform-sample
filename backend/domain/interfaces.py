"""
Domain Interfaces - Abstract contracts for Clean Architecture.

These interfaces define the contracts that must be implemented by infrastructure
components. They use Python's @abstractmethod decorator to enforce implementation
in concrete classes, ensuring loose coupling between layers.

The @abstractmethod decorator:
- Forces subclasses to implement the decorated method
- Prevents instantiation of abstract classes
- Provides compile-time checking for interface compliance
- Enables dependency inversion (depend on abstractions, not concretions)

Example:
    class ConcreteService(IProvisioningService):
        def submit_request(self, request):  # Must implement this
            # Implementation here
            pass
"""

from abc import ABC, abstractmethod
from typing import List, Optional

from .models import ProvisioningRequest


class IProvisioningService(ABC):
    """
    Abstract interface for provisioning service operations.
    
    This interface defines the contract for submitting and managing
    infrastructure provisioning requests. Concrete implementations
    might use different backends (file queue, Redis, SQS, etc.).
    """
    
    @abstractmethod
    async def submit_request(self, request: ProvisioningRequest) -> str:
        """
        Submit a provisioning request for processing.
        
        Args:
            request: The provisioning request to submit
            
        Returns:
            str: The request ID for tracking
            
        Raises:
            ProvisioningError: If submission fails
        """
        pass
    
    @abstractmethod
    async def get_request_status(self, request_id: str) -> Optional[ProvisioningRequest]:
        """
        Retrieve the current status of a provisioning request.
        
        Args:
            request_id: The unique identifier of the request
            
        Returns:
            ProvisioningRequest: The request with current status, or None if not found
        """
        pass
    
    @abstractmethod
    async def list_requests(self, requester: Optional[str] = None) -> List[ProvisioningRequest]:
        """
        List provisioning requests, optionally filtered by requester.
        
        Args:
            requester: Optional username to filter requests
            
        Returns:
            List[ProvisioningRequest]: List of matching requests
        """
        pass
    
    @abstractmethod
    async def update_request_status(self, request_id: str, status_update: dict) -> bool:
        """
        Update the status of a provisioning request.
        
        This method is typically called by external processes (scripts, CI/CD)
        to update request status after Terraform execution.
        
        Args:
            request_id: The unique identifier of the request
            status_update: Dictionary containing status and optional output/error
            
        Returns:
            bool: True if update was successful, False otherwise
        """
        pass


class IRequestQueue(ABC):
    """
    Abstract interface for request queue operations.
    
    This interface abstracts the mechanism used to queue and process
    provisioning requests. It could be implemented using files, databases,
    message queues, or any other persistence mechanism.
    """
    
    @abstractmethod
    async def enqueue(self, request: ProvisioningRequest) -> bool:
        """
        Add a request to the processing queue.
        
        Args:
            request: The provisioning request to queue
            
        Returns:
            bool: True if successfully queued, False otherwise
        """
        pass
    
    @abstractmethod
    async def dequeue(self) -> Optional[ProvisioningRequest]:
        """
        Remove and return the next request from the queue.
        
        Returns:
            ProvisioningRequest: The next request to process, or None if queue is empty
        """
        pass
    
    @abstractmethod
    async def peek(self) -> List[ProvisioningRequest]:
        """
        View pending requests without removing them from the queue.
        
        Returns:
            List[ProvisioningRequest]: List of pending requests
        """
        pass


class IRequestRepository(ABC):
    """
    Abstract interface for request persistence operations.
    
    This interface handles the storage and retrieval of provisioning requests,
    separate from the queue mechanism. This allows for tracking request history
    and status updates even after processing is complete.
    """
    
    @abstractmethod
    async def save(self, request: ProvisioningRequest) -> bool:
        """
        Persist a provisioning request.
        
        Args:
            request: The request to save
            
        Returns:
            bool: True if successfully saved, False otherwise
        """
        pass
    
    @abstractmethod
    async def find_by_id(self, request_id: str) -> Optional[ProvisioningRequest]:
        """
        Find a request by its unique identifier.
        
        Args:
            request_id: The unique identifier of the request
            
        Returns:
            ProvisioningRequest: The matching request, or None if not found
        """
        pass
    
    @abstractmethod
    async def find_by_requester(self, requester: str) -> List[ProvisioningRequest]:
        """
        Find all requests submitted by a specific user.
        
        Args:
            requester: The username to search for
            
        Returns:
            List[ProvisioningRequest]: List of matching requests
        """
        pass
    
    @abstractmethod
    async def update(self, request: ProvisioningRequest) -> bool:
        """
        Update an existing request.
        
        Args:
            request: The request with updated information
            
        Returns:
            bool: True if successfully updated, False otherwise
        """
        pass
