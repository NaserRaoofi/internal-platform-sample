import React, { useState, useEffect } from 'react';

interface Request {
  id: string;
  request_type: string;
  title: string;
  description: string;
  requested_by: string;
  requester_role: string;
  configuration: any;
  status: string;
  created_at: string;
  updated_at: string;
  reviewed_by?: string;
  reviewed_at?: string;
  rejection_reason?: string;
  deployment_job_id?: string;
  estimated_cost: number;
}

interface AdminRequestsProps {
  userRole: string;
}

export const AdminRequests: React.FC<AdminRequestsProps> = ({ userRole }) => {
  const [pendingRequests, setPendingRequests] = useState<Request[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedRequest, setSelectedRequest] = useState<Request | null>(null);
  const [reviewAction, setReviewAction] = useState<'approve' | 'reject' | null>(null);
  const [rejectionReason, setRejectionReason] = useState('');

  useEffect(() => {
    if (userRole === 'admin') {
      fetchPendingRequests();
    }
  }, [userRole]);

  const fetchPendingRequests = async () => {
    try {
      // Read requests from localStorage instead of backend API
      const requests = JSON.parse(localStorage.getItem('pending-requests') || '[]');
      const pendingOnly = requests.filter((req: Request) => req.status === 'pending');
      setPendingRequests(pendingOnly);
    } catch (error) {
      console.error('Failed to fetch pending requests:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleReviewRequest = async (requestId: string, decision: 'approve' | 'reject', reason?: string) => {
    try {
      // Update request status in localStorage
      const requests = JSON.parse(localStorage.getItem('pending-requests') || '[]');
      const requestIndex = requests.findIndex((req: Request) => req.id === requestId);
      
      if (requestIndex === -1) {
        console.error('Request not found');
        return;
      }

      const request = requests[requestIndex];
      request.status = decision === 'approve' ? 'approved' : 'rejected';
      request.reviewed_by = 'admin-user'; // In real app, get from auth
      request.reviewed_at = new Date().toISOString();
      request.updated_at = new Date().toISOString();
      
      if (decision === 'reject' && reason) {
        request.rejection_reason = reason;
      }

      // If approved, simulate deployment
      if (decision === 'approve') {
        // Simulate calling the backend deployment
        const deploymentResponse = await simulateDeployment(request);
        if (deploymentResponse.success) {
          request.status = 'deployed';
          request.deployment_job_id = deploymentResponse.job_id;
          alert(`✅ Request approved and deployed successfully! Job ID: ${deploymentResponse.job_id}`);
        } else {
          request.status = 'failed';
          request.rejection_reason = deploymentResponse.error;
          alert(`❌ Deployment failed: ${deploymentResponse.error}`);
        }
      }

      // Update localStorage
      localStorage.setItem('pending-requests', JSON.stringify(requests));
      
      // Refresh the list
      await fetchPendingRequests();
      setSelectedRequest(null);
      setReviewAction(null);
      setRejectionReason('');
      
    } catch (error) {
      console.error('Error reviewing request:', error);
    }
  };

  const simulateDeployment = async (request: Request) => {
    // Simulate deployment process (in real app, this would call the backend)
    try {
      // Mock deployment delay
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      // Simulate success/failure (90% success rate)
      const success = Math.random() > 0.1;
      
      if (success) {
        return {
          success: true,
          job_id: `JOB-${Date.now()}`
        };
      } else {
        return {
          success: false,
          error: 'Resource name already exists in AWS'
        };
      }
    } catch (error) {
      return {
        success: false,
        error: 'Deployment service unavailable'
      };
    }
  };

  if (userRole !== 'admin') {
    return (
      <div className="text-center py-8">
        <p className="text-red-600">Access denied. Admin privileges required.</p>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="text-center py-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500 mx-auto"></div>
        <p className="mt-2">Loading pending requests...</p>
      </div>
    );
  }

  return (
    <div className="max-w-6xl mx-auto p-6">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Admin Dashboard - Pending Requests</h1>
        <p className="text-gray-600 mt-2">Review and approve infrastructure deployment requests</p>
      </div>

      {pendingRequests.length === 0 ? (
        <div className="text-center py-8 bg-gray-50 rounded-lg">
          <p className="text-gray-500">No pending requests at this time</p>
        </div>
      ) : (
        <div className="space-y-4">
          {pendingRequests.map((request) => (
            <div key={request.id} className="bg-white border border-gray-200 rounded-lg p-6 shadow-sm">
              <div className="flex justify-between items-start mb-4">
                <div>
                  <h3 className="text-lg font-semibold text-gray-900">{request.title}</h3>
                  <p className="text-gray-600 text-sm">{request.description}</p>
                  <div className="flex space-x-4 mt-2 text-xs text-gray-500">
                    <span>Requested by: <span className="font-medium">{request.requested_by}</span></span>
                    <span>Type: <span className="font-medium">{request.request_type}</span></span>
                    <span>Cost: <span className="font-medium">${request.estimated_cost}/month</span></span>
                    <span>Created: <span className="font-medium">{new Date(request.created_at).toLocaleString()}</span></span>
                  </div>
                </div>
                <div className="flex space-x-2">
                  <button
                    onClick={() => setSelectedRequest(request)}
                    className="px-3 py-1 bg-blue-500 text-white text-sm rounded hover:bg-blue-600"
                  >
                    View Details
                  </button>
                  <button
                    onClick={() => handleReviewRequest(request.id, 'approve')}
                    className="px-3 py-1 bg-green-500 text-white text-sm rounded hover:bg-green-600"
                  >
                    Approve & Deploy
                  </button>
                  <button
                    onClick={() => {
                      setSelectedRequest(request);
                      setReviewAction('reject');
                    }}
                    className="px-3 py-1 bg-red-500 text-white text-sm rounded hover:bg-red-600"
                  >
                    Reject
                  </button>
                </div>
              </div>
              
              {request.request_type === 's3_bucket' && (
                <div className="bg-gray-50 p-3 rounded text-sm">
                  <strong>Configuration:</strong> S3 bucket '{request.configuration.bucketName}' in {request.configuration.environment} environment
                  {request.configuration.ec2Enabled && (
                    <span> with EC2 instance ({request.configuration.ec2InstanceType})</span>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Request Details Modal */}
      {selectedRequest && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg p-6 max-w-2xl w-full max-h-screen overflow-y-auto">
            <div className="flex justify-between items-start mb-4">
              <h2 className="text-xl font-bold">Request Details</h2>
              <button
                onClick={() => {
                  setSelectedRequest(null);
                  setReviewAction(null);
                  setRejectionReason('');
                }}
                className="text-gray-500 hover:text-gray-700"
              >
                ✕
              </button>
            </div>
            
            <div className="space-y-4">
              <div>
                <h3 className="font-semibold">Basic Information</h3>
                <div className="grid grid-cols-2 gap-4 mt-2 text-sm">
                  <div><strong>ID:</strong> {selectedRequest.id}</div>
                  <div><strong>Type:</strong> {selectedRequest.request_type}</div>
                  <div><strong>Status:</strong> {selectedRequest.status}</div>
                  <div><strong>Requested by:</strong> {selectedRequest.requested_by}</div>
                  <div><strong>Cost:</strong> ${selectedRequest.estimated_cost}/month</div>
                  <div><strong>Created:</strong> {new Date(selectedRequest.created_at).toLocaleString()}</div>
                </div>
              </div>
              
              <div>
                <h3 className="font-semibold">Configuration</h3>
                <pre className="bg-gray-100 p-3 rounded text-xs overflow-x-auto mt-2">
                  {JSON.stringify(selectedRequest.configuration, null, 2)}
                </pre>
              </div>

              {reviewAction === 'reject' && (
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Rejection Reason *
                  </label>
                  <textarea
                    value={rejectionReason}
                    onChange={(e) => setRejectionReason(e.target.value)}
                    className="w-full p-3 border border-gray-300 rounded-md focus:ring-2 focus:ring-red-500"
                    rows={4}
                    placeholder="Please provide a reason for rejection..."
                    required
                  />
                </div>
              )}
              
              <div className="flex space-x-2 pt-4 border-t">
                {reviewAction === 'reject' ? (
                  <>
                    <button
                      onClick={() => handleReviewRequest(selectedRequest.id, 'reject', rejectionReason)}
                      disabled={!rejectionReason.trim()}
                      className="px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600 disabled:opacity-50"
                    >
                      Confirm Rejection
                    </button>
                    <button
                      onClick={() => setReviewAction(null)}
                      className="px-4 py-2 bg-gray-300 text-gray-700 rounded hover:bg-gray-400"
                    >
                      Cancel
                    </button>
                  </>
                ) : (
                  <>
                    <button
                      onClick={() => handleReviewRequest(selectedRequest.id, 'approve')}
                      className="px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600"
                    >
                      Approve & Deploy
                    </button>
                    <button
                      onClick={() => setReviewAction('reject')}
                      className="px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600"
                    >
                      Reject
                    </button>
                  </>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AdminRequests;
