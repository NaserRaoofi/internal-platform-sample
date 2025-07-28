"""
Infrastructure Adapters - External service implementations.

This layer contains concrete implementations of the domain interfaces,
handling external concerns like file I/O, queuing, and persistence.
"""

import json
import os
import asyncio
from pathlib import Path
from typing import List, Optional, Dict, Any
from datetime import datetime

from ..domain.interfaces import IProvisioningService, IRequestQueue, IRequestRepository
from ..domain.models import ProvisioningRequest, RequestStatus


class FileBasedRequestQueue(IRequestQueue):
    """File-based implementation of request queue using JSON files."""
    
    def __init__(self, queue_dir: str = "queue"):
        self.queue_dir = Path(queue_dir)
        self.pending_dir = self.queue_dir / "pending"
        self.processing_dir = self.queue_dir / "processing"
        self.completed_dir = self.queue_dir / "completed"
        
        # Create directories if they don't exist
        for dir_path in [self.pending_dir, self.processing_dir, self.completed_dir]:
            dir_path.mkdir(parents=True, exist_ok=True)
    
    async def enqueue(self, request: ProvisioningRequest) -> bool:
        """Add a request to the pending queue."""
        try:
            file_path = self.pending_dir / f"{request.id}.json"
            with open(file_path, 'w') as f:
                json.dump(request.model_dump(), f, indent=2, default=str)
            return True
        except Exception as e:
            print(f"Failed to enqueue request {request.id}: {e}")
            return False
    
    async def dequeue(self) -> Optional[ProvisioningRequest]:
        """Remove and return the next request from the pending queue."""
        try:
            pending_files = list(self.pending_dir.glob("*.json"))
            if not pending_files:
                return None
            
            # Get the oldest file
            oldest_file = min(pending_files, key=lambda x: x.stat().st_ctime)
            
            # Read the request
            with open(oldest_file, 'r') as f:
                request_data = json.load(f)
            
            request = ProvisioningRequest(**request_data)
            
            # Move to processing directory
            processing_file = self.processing_dir / oldest_file.name
            oldest_file.rename(processing_file)
            
            return request
            
        except Exception as e:
            print(f"Failed to dequeue request: {e}")
            return None
    
    async def peek(self) -> List[ProvisioningRequest]:
        """View pending requests without removing them."""
        requests = []
        try:
            for file_path in self.pending_dir.glob("*.json"):
                with open(file_path, 'r') as f:
                    request_data = json.load(f)
                requests.append(ProvisioningRequest(**request_data))
        except Exception as e:
            print(f"Failed to peek queue: {e}")
        
        return sorted(requests, key=lambda x: x.created_at)


class FileBasedRequestRepository(IRequestRepository):
    """File-based implementation of request repository using JSON files."""
    
    def __init__(self, storage_dir: str = "storage"):
        self.storage_dir = Path(storage_dir)
        self.storage_dir.mkdir(parents=True, exist_ok=True)
    
    def _get_file_path(self, request_id: str) -> Path:
        """Get the file path for a request ID."""
        return self.storage_dir / f"{request_id}.json"
    
    async def save(self, request: ProvisioningRequest) -> bool:
        """Save a request to storage."""
        try:
            file_path = self._get_file_path(request.id)
            with open(file_path, 'w') as f:
                json.dump(request.model_dump(), f, indent=2, default=str)
            return True
        except Exception as e:
            print(f"Failed to save request {request.id}: {e}")
            return False
    
    async def find_by_id(self, request_id: str) -> Optional[ProvisioningRequest]:
        """Find a request by ID."""
        try:
            file_path = self._get_file_path(request_id)
            if not file_path.exists():
                return None
            
            with open(file_path, 'r') as f:
                request_data = json.load(f)
            
            return ProvisioningRequest(**request_data)
        except Exception as e:
            print(f"Failed to find request {request_id}: {e}")
            return None
    
    async def find_by_requester(self, requester: str) -> List[ProvisioningRequest]:
        """Find all requests by a specific requester."""
        requests = []
        try:
            for file_path in self.storage_dir.glob("*.json"):
                with open(file_path, 'r') as f:
                    request_data = json.load(f)
                
                request = ProvisioningRequest(**request_data)
                if request.requester == requester:
                    requests.append(request)
        except Exception as e:
            print(f"Failed to find requests for requester {requester}: {e}")
        
        return sorted(requests, key=lambda x: x.created_at, reverse=True)
    
    async def update(self, request: ProvisioningRequest) -> bool:
        """Update an existing request."""
        request.updated_at = datetime.utcnow()
        return await self.save(request)


class QueueProvisioningService(IProvisioningService):
    """
    Implementation of provisioning service using file-based queue and repository.
    
    This service writes requests to a queue for external processing (Terraform scripts)
    and maintains request state in a repository for tracking and status updates.
    """
    
    def __init__(self, queue: IRequestQueue, repository: IRequestRepository):
        self.queue = queue
        self.repository = repository
    
    async def submit_request(self, request: ProvisioningRequest) -> str:
        """Submit a provisioning request to the queue."""
        # Save to repository for tracking
        await self.repository.save(request)
        
        # Add to queue for processing
        success = await self.queue.enqueue(request)
        if not success:
            raise Exception(f"Failed to queue request {request.id}")
        
        return request.id
    
    async def get_request_status(self, request_id: str) -> Optional[ProvisioningRequest]:
        """Get the current status of a request."""
        return await self.repository.find_by_id(request_id)
    
    async def list_requests(self, requester: Optional[str] = None) -> List[ProvisioningRequest]:
        """List requests, optionally filtered by requester."""
        if requester:
            return await self.repository.find_by_requester(requester)
        
        # If no requester specified, return all requests
        # This is a simple implementation - in production you might want pagination
        requests = []
        storage_dir = Path("storage")
        if storage_dir.exists():
            for file_path in storage_dir.glob("*.json"):
                try:
                    with open(file_path, 'r') as f:
                        request_data = json.load(f)
                    requests.append(ProvisioningRequest(**request_data))
                except Exception as e:
                    print(f"Failed to load request from {file_path}: {e}")
        
        return sorted(requests, key=lambda x: x.created_at, reverse=True)
    
    async def update_request_status(self, request_id: str, status_update: dict) -> bool:
        """Update request status (typically called by external processes)."""
        request = await self.repository.find_by_id(request_id)
        if not request:
            return False
        
        # Update status based on provided information
        if "status" in status_update:
            request.status = RequestStatus(status_update["status"])
        
        if "error_message" in status_update:
            request.error_message = status_update["error_message"]
        
        if "terraform_output" in status_update:
            request.terraform_output = status_update["terraform_output"]
        
        request.updated_at = datetime.utcnow()
        
        return await self.repository.update(request)
    
    async def approve_request(self, request_id: str, approver: str) -> bool:
        """Approve a provisioning request."""
        request = await self.repository.find_by_id(request_id)
        if not request:
            return False
        
        # Mark as approved and queue for processing
        request.mark_approved(approver)
        request.mark_in_progress()
        
        # Update repository
        await self.repository.update(request)
        
        # Add to processing queue
        success = await self.queue.enqueue(request)
        return success
    
    async def reject_request(self, request_id: str, approver: str, reason: str = "") -> bool:
        """Reject a provisioning request."""
        request = await self.repository.find_by_id(request_id)
        if not request:
            return False
        
        # Mark as rejected
        request.mark_rejected(approver, reason)
        
        # Update repository
        return await self.repository.update(request)


def create_provisioning_service() -> IProvisioningService:
    """Factory function to create a configured provisioning service."""
    queue = FileBasedRequestQueue()
    repository = FileBasedRequestRepository()
    return QueueProvisioningService(queue, repository)
