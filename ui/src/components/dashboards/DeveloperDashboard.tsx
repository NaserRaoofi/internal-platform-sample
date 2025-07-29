import React from 'react';
import { useEffect, useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
import { Button } from '../ui/button';
import { Badge } from '../ui/badge';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../ui/table';
import { DeployServiceForm } from '../forms/DeployServiceForm';
import { useAppStore } from '../../store/appStore';

export function DeveloperDashboard() {
  const { 
    requests, 
    loading, 
    error, 
    fetchRequests 
  } = useAppStore();
  
  const [showDeployForm, setShowDeployForm] = useState(false);

  useEffect(() => {
    fetchRequests();
  }, [fetchRequests]);

    // Filter requests for current user (in a real app, this would come from auth)
  const currentUser = 'developer1'; // Mock current user
  const myRequests = requests.filter(req => req.requester === currentUser);
  const pendingRequests = myRequests.filter(req => req.status === 'PENDING').length;
  const runningServices = myRequests.filter(req => req.status === 'COMPLETED').length;
  const failedDeployments = myRequests.filter(req => req.status === 'FAILED').length;

  const getStatusBadge = (status: string) => {
    const variants: Record<string, any> = {
      PENDING: { variant: 'warning', label: 'Pending Approval' },
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

  if (showDeployForm) {
    return (
      <div className="space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold">Deploy New Service</h1>
            <p className="text-muted-foreground">Create a new service deployment request</p>
          </div>
          <Button variant="outline" onClick={() => setShowDeployForm(false)}>
            ← Back to Dashboard
          </Button>
        </div>
        
        <DeployServiceForm
          onSubmit={() => {
            setShowDeployForm(false);
            fetchRequests(); // Refresh the list
          }}
          onCancel={() => setShowDeployForm(false)}
        />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Developer Dashboard</h1>
          <p className="text-muted-foreground">
            Welcome back, {currentUser}! Manage your services and deployments.
          </p>
        </div>
        <Button onClick={() => setShowDeployForm(true)}>
          🚀 Deploy New Service
        </Button>
      </div>

      {/* Quick Stats */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Running Services</CardTitle>
            <span className="text-2xl">🟢</span>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{runningServices}</div>
            <p className="text-xs text-muted-foreground">
              Active deployments
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Pending Approval</CardTitle>
            <span className="text-2xl">⏳</span>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{pendingRequests}</div>
            <p className="text-xs text-muted-foreground">
              Awaiting admin review
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Failed Deployments</CardTitle>
            <span className="text-2xl">❌</span>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{failedDeployments}</div>
            <p className="text-xs text-muted-foreground">
              Need attention
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Total Requests</CardTitle>
            <span className="text-2xl">📊</span>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{myRequests.length}</div>
            <p className="text-xs text-muted-foreground">
              All time
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Quick Actions */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        <Card className="cursor-pointer hover:shadow-md transition-shadow" 
              onClick={() => setShowDeployForm(true)}>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              🚀 Deploy Service
            </CardTitle>
            <CardDescription>
              Deploy a new web application or API service
            </CardDescription>
          </CardHeader>
        </Card>

        <Card className="cursor-pointer hover:shadow-md transition-shadow">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              🔍 View Logs
            </CardTitle>
            <CardDescription>
              Check application logs and monitoring data
            </CardDescription>
          </CardHeader>
        </Card>

        <Card className="cursor-pointer hover:shadow-md transition-shadow">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              🔄 Feature Environment
            </CardTitle>
            <CardDescription>
              Create ephemeral environment for testing
            </CardDescription>
          </CardHeader>
        </Card>
      </div>

      {/* Recent Requests */}
      <Card>
        <CardHeader>
          <CardTitle>Recent Requests</CardTitle>
          <CardDescription>
            Your latest service deployment requests
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
          ) : myRequests.length === 0 ? (
            <div className="text-center p-8 text-muted-foreground">
              No requests yet. Deploy your first service to get started!
            </div>
          ) : (
            <div className="rounded-md border">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Service Name</TableHead>
                    <TableHead>Type</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Created</TableHead>
                    <TableHead>Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {myRequests.slice(0, 10).map((request) => (
                    <TableRow key={request.id}>
                      <TableCell className="font-medium">
                        {request.resource_config?.serviceName || request.resource_config?.service_name || 'Unknown'}
                      </TableCell>
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
                      <TableCell>
                        <div className="flex gap-2">
                          <Button variant="outline" size="sm">
                            View
                          </Button>
                          {request.status === 'COMPLETED' && (
                            <Button variant="outline" size="sm">
                              Logs
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
    </div>
  );
}
