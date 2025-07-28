import React, { useEffect, useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
import { Button } from '../ui/button';
import { Badge } from '../ui/badge';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../ui/table';
import { Input } from '../ui/input';
import { Label } from '../ui/label';
import { useAppStore } from '../../store/appStore';

export function AdminDashboard() {
  const { 
    requests, 
    loading, 
    error, 
    fetchRequests,
    approveRequest,
    rejectRequest 
  } = useAppStore();
  
  const [selectedRequest, setSelectedRequest] = useState<string | null>(null);
  const [rejectReason, setRejectReason] = useState('');
  const [showRejectForm, setShowRejectForm] = useState(false);

  useEffect(() => {
    fetchRequests();
  }, [fetchRequests]);

  const pendingRequests = requests.filter(req => req.status === 'PENDING');
  const processingRequests = requests.filter(req => req.status === 'PROCESSING');
  const completedRequests = requests.filter(req => req.status === 'COMPLETED');
  const failedRequests = requests.filter(req => req.status === 'FAILED');

  const handleApprove = async (requestId: string) => {
    try {
      await approveRequest(requestId);
    } catch (error) {
      console.error('Failed to approve request:', error);
    }
  };

  const handleReject = async (requestId: string) => {
    setSelectedRequest(requestId);
    setShowRejectForm(true);
  };

  const submitRejection = async () => {
    if (selectedRequest && rejectReason.trim()) {
      try {
        await rejectRequest(selectedRequest, rejectReason);
        setShowRejectForm(false);
        setSelectedRequest(null);
        setRejectReason('');
      } catch (error) {
        console.error('Failed to reject request:', error);
      }
    }
  };

  const getStatusBadge = (status: string) => {
    const variants: Record<string, any> = {
      PENDING: { variant: 'warning', label: 'Pending Review' },
      APPROVED: { variant: 'default', label: 'Approved' },
      REJECTED: { variant: 'destructive', label: 'Rejected' },
      PROCESSING: { variant: 'default', label: 'Processing' },
      COMPLETED: { variant: 'success', label: 'Completed' },
      FAILED: { variant: 'destructive', label: 'Failed' }
    };
    
    const config = variants[status] || { variant: 'secondary', label: status };
    return <Badge variant={config.variant}>{config.label}</Badge>;
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const getPriorityBadge = (resourceType: string) => {
    const priorities: Record<string, any> = {
      WEB_APP: { variant: 'default', label: 'Normal' },
      API_SERVICE: { variant: 'secondary', label: 'Normal' },
      DATA_PIPELINE: { variant: 'warning', label: 'High' }
    };
    
    const config = priorities[resourceType] || { variant: 'outline', label: 'Normal' };
    return <Badge variant={config.variant}>{config.label}</Badge>;
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Admin Dashboard</h1>
          <p className="text-muted-foreground">
            Monitor and approve infrastructure deployment requests
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" onClick={fetchRequests}>
            🔄 Refresh
          </Button>
          <Button variant="outline">
            📊 Analytics
          </Button>
        </div>
      </div>

      {/* System Overview */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Pending Approval</CardTitle>
            <span className="text-2xl">⏳</span>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{pendingRequests.length}</div>
            <p className="text-xs text-muted-foreground">
              Require your review
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Processing</CardTitle>
            <span className="text-2xl">⚙️</span>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{processingRequests.length}</div>
            <p className="text-xs text-muted-foreground">
              Currently deploying
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Active Services</CardTitle>
            <span className="text-2xl">🟢</span>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{completedRequests.length}</div>
            <p className="text-xs text-muted-foreground">
              Running successfully
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Failed Deployments</CardTitle>
            <span className="text-2xl">❌</span>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{failedRequests.length}</div>
            <p className="text-xs text-muted-foreground">
              Need attention
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Pending Approvals */}
      {pendingRequests.length > 0 && (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              ⚠️ Pending Approvals ({pendingRequests.length})
            </CardTitle>
            <CardDescription>
              Requests waiting for admin approval
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="rounded-md border">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Service Name</TableHead>
                    <TableHead>Requester</TableHead>
                    <TableHead>Type</TableHead>
                    <TableHead>Priority</TableHead>
                    <TableHead>Requested</TableHead>
                    <TableHead>Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {pendingRequests.map((request) => (
                    <TableRow key={request.id}>
                      <TableCell className="font-medium">
                        {request.resource_config?.serviceName || request.resource_config?.service_name || 'Unknown'}
                      </TableCell>
                      <TableCell>{request.requester}</TableCell>
                      <TableCell>
                        <Badge variant="outline">
                          {request.resource_type.replace('_', ' ')}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        {getPriorityBadge(request.resource_type)}
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {formatDate(request.created_at)}
                      </TableCell>
                      <TableCell>
                        <div className="flex gap-2">
                          <Button 
                            variant="default" 
                            size="sm"
                            onClick={() => handleApprove(request.id)}
                            disabled={loading}
                          >
                            ✅ Approve
                          </Button>
                          <Button 
                            variant="destructive" 
                            size="sm"
                            onClick={() => handleReject(request.id)}
                            disabled={loading}
                          >
                            ❌ Reject
                          </Button>
                          <Button variant="outline" size="sm">
                            👁️ Details
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          </CardContent>
        </Card>
      )}

      {/* All Requests */}
      <Card>
        <CardHeader>
          <CardTitle>All Deployment Requests</CardTitle>
          <CardDescription>
            Complete history of infrastructure requests
          </CardDescription>
        </CardHeader>
        <CardContent>
          {loading ? (
            <div className="flex items-center justify-center p-8">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
            </div>
          ) : error ? (
            <div className="text-center p-8 text-destructive">
              Error loading requests: {error}
            </div>
          ) : requests.length === 0 ? (
            <div className="text-center p-8 text-muted-foreground">
              No deployment requests found.
            </div>
          ) : (
            <div className="rounded-md border">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Service Name</TableHead>
                    <TableHead>Requester</TableHead>
                    <TableHead>Type</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Created</TableHead>
                    <TableHead>Updated</TableHead>
                    <TableHead>Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {requests.slice(0, 20).map((request) => (
                    <TableRow key={request.id}>
                      <TableCell className="font-medium">
                        {request.resource_config?.serviceName || request.resource_config?.service_name || 'Unknown'}
                      </TableCell>
                      <TableCell>{request.requester}</TableCell>
                      <TableCell>
                        <Badge variant="outline">
                          {request.resource_type.replace('_', ' ')}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        {getStatusBadge(request.status)}
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {formatDate(request.created_at)}
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {request.updated_at ? formatDate(request.updated_at) : '-'}
                      </TableCell>
                      <TableCell>
                        <div className="flex gap-2">
                          <Button variant="outline" size="sm">
                            📋 Details
                          </Button>
                          {request.status === 'COMPLETED' && (
                            <Button variant="outline" size="sm">
                              📊 Logs
                            </Button>
                          )}
                          {request.status === 'FAILED' && (
                            <Button variant="outline" size="sm">
                              🔧 Debug
                            </Button>
                          )}
                        </div>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Reject Modal */}
      {showRejectForm && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <Card className="w-full max-w-md">
            <CardHeader>
              <CardTitle>Reject Request</CardTitle>
              <CardDescription>
                Please provide a reason for rejecting this deployment request
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div>
                <Label htmlFor="reason">Rejection Reason</Label>
                <Input
                  id="reason"
                  value={rejectReason}
                  onChange={(e) => setRejectReason(e.target.value)}
                  placeholder="e.g., Security concerns, insufficient resources..."
                />
              </div>
              <div className="flex gap-2 justify-end">
                <Button 
                  variant="outline" 
                  onClick={() => {
                    setShowRejectForm(false);
                    setSelectedRequest(null);
                    setRejectReason('');
                  }}
                >
                  Cancel
                </Button>
                <Button 
                  variant="destructive"
                  onClick={submitRejection}
                  disabled={!rejectReason.trim() || loading}
                >
                  Reject Request
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}
    </div>
  );
}
