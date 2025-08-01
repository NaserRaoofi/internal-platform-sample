"""
API endpoints for infrastructure request management and approval workflow.
"""
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Dict, Any, Optional

from domain.models import JobRequest, JobResult, JobStatus
from infrastructure.database import get_db_session

router = APIRouter(prefix="/api/v1/requests", tags=["requests"])


class CreateRequestModel(BaseModel):
    """Model for creating new infrastructure requests."""
    request_type: str
    title: str
    description: str
    configuration: Dict[str, Any]
    estimated_cost: float = 0.0


class ApprovalDecisionModel(BaseModel):
    """Model for admin approval/rejection decisions."""
    decision: str  # "approve" or "reject"
    reason: Optional[str] = None  # Required for rejection


class RequestResponseModel(BaseModel):
    """Response model for request data."""
    id: str
    request_type: str
    title: str
    description: str
    requested_by: str
    requester_role: str
    configuration: Dict[str, Any]
    status: str
    created_at: str
    updated_at: str
    reviewed_by: Optional[str] = None
    reviewed_at: Optional[str] = None
    rejection_reason: Optional[str] = None
    deployment_job_id: Optional[str] = None
    estimated_cost: float


def get_request_service(db_session=Depends(get_db_session)) -> RequestService:
    """Dependency to get request service."""
    return RequestService(db_session)


def get_current_user() -> str:
    """Get current user from session/token. For demo, return hardcoded user."""
    # In real implementation, this would extract user from JWT token or session
    return "developer-user"


def get_current_user_role() -> str:
    """Get current user role. For demo, return based on simple logic."""
    # In real implementation, this would come from user claims/database
    user = get_current_user()
    if user == "admin-user":
        return "admin"
    return "developer"


@router.post("/", response_model=RequestResponseModel)
async def create_infrastructure_request(
    request_data: CreateRequestModel,
    request_service: RequestService = Depends(get_request_service),
    current_user: str = Depends(get_current_user),
    user_role: str = Depends(get_current_user_role)
):
    """
    Create a new infrastructure deployment request.
    Developers submit requests for admin approval.
    """
    try:
        # Map string to enum
        request_type_enum = RequestType(request_data.request_type)
        
        # Create the request
        request = request_service.create_request(
            request_type=request_type_enum,
            title=request_data.title,
            description=request_data.description,
            configuration=request_data.configuration,
            requested_by=current_user,
            requester_role=user_role,
            estimated_cost=request_data.estimated_cost
        )
        
        return RequestResponseModel(**request.to_dict())
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create request: {str(e)}")


@router.get("/pending", response_model=List[RequestResponseModel])
async def get_pending_requests(
    request_service: RequestService = Depends(get_request_service),
    user_role: str = Depends(get_current_user_role)
):
    """
    Get all pending requests for admin approval.
    Only admins can access this endpoint.
    """
    if user_role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    try:
        requests = request_service.get_requests_for_approval()
        return [RequestResponseModel(**req.to_dict()) for req in requests]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch requests: {str(e)}")


@router.get("/my-requests", response_model=List[RequestResponseModel])
async def get_my_requests(
    request_service: RequestService = Depends(get_request_service),
    current_user: str = Depends(get_current_user)
):
    """
    Get all requests submitted by the current user.
    """
    try:
        requests = request_service.get_user_requests(current_user)
        return [RequestResponseModel(**req.to_dict()) for req in requests]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch user requests: {str(e)}")


@router.get("/{request_id}", response_model=RequestResponseModel)
async def get_request_details(
    request_id: str,
    request_service: RequestService = Depends(get_request_service),
    current_user: str = Depends(get_current_user),
    user_role: str = Depends(get_current_user_role)
):
    """
    Get details of a specific request.
    Users can only see their own requests unless they're admin.
    """
    try:
        request = request_service.get_request_by_id(request_id)
        if not request:
            raise HTTPException(status_code=404, detail="Request not found")
        
        # Check permissions
        if user_role != "admin" and request.requested_by != current_user:
            raise HTTPException(status_code=403, detail="Access denied")
        
        return RequestResponseModel(**request.to_dict())
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch request: {str(e)}")


@router.post("/{request_id}/review", response_model=RequestResponseModel)
async def review_request(
    request_id: str,
    decision: ApprovalDecisionModel,
    request_service: RequestService = Depends(get_request_service),
    current_user: str = Depends(get_current_user),
    user_role: str = Depends(get_current_user_role)
):
    """
    Approve or reject a pending request.
    Only admins can review requests.
    """
    if user_role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    try:
        if decision.decision == "approve":
            request = request_service.approve_request(request_id, current_user)
        elif decision.decision == "reject":
            if not decision.reason:
                raise HTTPException(status_code=400, detail="Rejection reason is required")
            request = request_service.reject_request(request_id, current_user, decision.reason)
        else:
            raise HTTPException(status_code=400, detail="Decision must be 'approve' or 'reject'")
        
        return RequestResponseModel(**request.to_dict())
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to review request: {str(e)}")


@router.post("/{request_id}/deploy", response_model=Dict[str, str])
async def deploy_approved_request(
    request_id: str,
    request_service: RequestService = Depends(get_request_service),
    current_user: str = Depends(get_current_user),
    user_role: str = Depends(get_current_user_role)
):
    """
    Deploy an approved request.
    Only admins can trigger deployments.
    """
    if user_role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    try:
        request = request_service.get_request_by_id(request_id)
        if not request:
            raise HTTPException(status_code=404, detail="Request not found")
        
        if request.status != RequestStatus.APPROVED:
            raise HTTPException(status_code=400, detail="Request must be approved before deployment")
        
        # Here we would call the actual deployment service
        # For now, simulate the deployment process
        if request.request_type == RequestType.S3_BUCKET:
            # Import and call the existing S3 creation service
            from ..services import create_sirwan_test_s3_service
            
            # Convert request configuration to the format expected by the service
            config = request.configuration
            job_response = await create_sirwan_test_s3_service(config)
            
            # Update request with job ID
            request.mark_deployed(job_response["job_id"])
            request_service._save_request(request)
            
            return {
                "message": "Deployment initiated successfully",
                "job_id": job_response["job_id"],
                "request_id": request_id
            }
        else:
            raise HTTPException(status_code=400, detail=f"Deployment not supported for {request.request_type.value}")
        
    except HTTPException:
        raise
    except Exception as e:
        # Mark request as failed
        if 'request' in locals():
            request.mark_failed(str(e))
            request_service._save_request(request)
        
        raise HTTPException(status_code=500, detail=f"Deployment failed: {str(e)}")
