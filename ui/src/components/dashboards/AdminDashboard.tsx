/**
 * Professional Admin Dashboard - Enterprise-Grade Platform Management
 * 
 * A comprehensive, enterprise-grade admin dashboard following modern React patterns:
 * - TypeScript with strict typing and JSDoc documentation
 * - Component composition and reusability
 * - Performance optimization with useMemo/useCallback
 * - Accessibility (WCAG) compliance
 * - Clean Architecture principles
 * - Real-time monitoring and management capabilities
 * 
 * @author Senior Frontend Developer
 * @version 2.0.0
 */

import React, { useEffect, useState, useCallback, useMemo, Suspense } from 'react';
import { Link } from 'react-router-dom';
import { 
  Activity, 
  Server, 
  Database, 
  Users, 
  Shield, 
  Settings, 
  RefreshCw,
  Plus,
  TrendingUp,
  Clock,
  CheckCircle,
  XCircle,
  AlertCircle,
  Eye,
  Download,
  FileText,
  BarChart3,
  Zap,
  Globe,
  Lock,
  UserCheck,
  HardDrive,
  Network,
  AlertTriangle,
  CheckSquare,
  Calendar,
  Search
} from 'lucide-react';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
import { Button } from '../ui/button';
import { Badge } from '../ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../ui/tabs';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../ui/table';
import { Input } from '../ui/input';
import { Label } from '../ui/label';
import { useAppStore } from '../../store/appStore';
import { getDeploymentRequests, approveDeploymentRequest, type DeploymentRequest } from '../../services/apiClient';

// Types for better TypeScript support and maintainability
interface AdminMetricCardProps {
  title: string;
  value: string | number;
  description: string;
  icon: React.ReactNode;
  variant: 'success' | 'warning' | 'error' | 'info';
  trend?: {
    value: number;
    isPositive: boolean;
  };
}

interface SystemHealthMetrics {
  cpu: number;
  memory: number;
  disk: number;
  network: number;
  uptime: string;
}

interface PlatformStats {
  totalUsers: number;
  activeServices: number;
  totalRequests: number;
  successRate: number;
}

interface UserActivity {
  userId: string;
  username: string;
  lastActivity: string;
  actionsToday: number;
  role: string;
}

interface ServiceHealth {
  name: string;
  status: 'healthy' | 'warning' | 'error';
  uptime: string;
  responseTime: number;
  errorRate: number;
}

/**
 * Reusable metric card component for admin dashboard
 * Provides consistent styling and accessibility for key metrics
 */
const AdminMetricCard: React.FC<AdminMetricCardProps> = React.memo(({ 
  title, 
  value, 
  description, 
  icon, 
  variant,
  trend 
}) => {
  const variantStyles = {
    success: 'border-green-200 bg-green-50 dark:border-green-800 dark:bg-green-950',
    warning: 'border-yellow-200 bg-yellow-50 dark:border-yellow-800 dark:bg-yellow-950',
    error: 'border-red-200 bg-red-50 dark:border-red-800 dark:bg-red-950',
    info: 'border-blue-200 bg-blue-50 dark:border-blue-800 dark:bg-blue-950'
  };

  return (
    <Card 
      className={`transition-all duration-200 hover:shadow-md ${variantStyles[variant]}`}
      role="article"
      aria-label={`${title} metric`}
    >
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">
          {title}
        </CardTitle>
        <div className="h-4 w-4 text-muted-foreground" aria-hidden="true">
          {icon}
        </div>
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold" aria-live="polite">
          {typeof value === 'number' ? value.toLocaleString() : value}
        </div>
        <div className="flex items-center justify-between">
          <p className="text-xs text-muted-foreground">
            {description}
          </p>
          {trend && (
            <div className={`flex items-center text-xs ${
              trend.isPositive ? 'text-green-600' : 'text-red-600'
            }`}>
              <TrendingUp className={`h-3 w-3 mr-1 ${
                !trend.isPositive ? 'rotate-180' : ''
              }`} />
              {Math.abs(trend.value)}%
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
});

AdminMetricCard.displayName = 'AdminMetricCard';

/**
 * System Health Monitor Component
 * Real-time monitoring of platform infrastructure
 */
const SystemHealthMonitor: React.FC = React.memo(() => {
  const [systemMetrics, setSystemMetrics] = useState<SystemHealthMetrics>({
    cpu: 0,
    memory: 0,
    disk: 0,
    network: 0,
    uptime: '0 days'
  });

  // Simulate real-time metrics (replace with actual API calls)
  useEffect(() => {
    const interval = setInterval(() => {
      setSystemMetrics({
        cpu: Math.floor(Math.random() * 100),
        memory: Math.floor(Math.random() * 100),
        disk: Math.floor(Math.random() * 100),
        network: Math.floor(Math.random() * 1000),
        uptime: `${Math.floor(Math.random() * 365)} days`
      });
    }, 5000);

    return () => clearInterval(interval);
  }, []);

  return (
    <div className="space-y-4">
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Activity className="h-4 w-4" />
              CPU Usage
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{systemMetrics.cpu}%</div>
            <div className="w-full bg-gray-200 rounded-full h-2 mt-2">
              <div 
                className={`h-2 rounded-full transition-all duration-500 ${
                  systemMetrics.cpu > 80 ? 'bg-red-500' : 
                  systemMetrics.cpu > 60 ? 'bg-yellow-500' : 'bg-green-500'
                }`}
                style={{ width: `${systemMetrics.cpu}%` }}
              />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <HardDrive className="h-4 w-4" />
              Memory
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{systemMetrics.memory}%</div>
            <div className="w-full bg-gray-200 rounded-full h-2 mt-2">
              <div 
                className={`h-2 rounded-full transition-all duration-500 ${
                  systemMetrics.memory > 80 ? 'bg-red-500' : 
                  systemMetrics.memory > 60 ? 'bg-yellow-500' : 'bg-green-500'
                }`}
                style={{ width: `${systemMetrics.memory}%` }}
              />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Database className="h-4 w-4" />
              Disk Usage
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{systemMetrics.disk}%</div>
            <div className="w-full bg-gray-200 rounded-full h-2 mt-2">
              <div 
                className={`h-2 rounded-full transition-all duration-500 ${
                  systemMetrics.disk > 80 ? 'bg-red-500' : 
                  systemMetrics.disk > 60 ? 'bg-yellow-500' : 'bg-green-500'
                }`}
                style={{ width: `${systemMetrics.disk}%` }}
              />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Network className="h-4 w-4" />
              Network
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{systemMetrics.network} MB/s</div>
            <p className="text-xs text-muted-foreground mt-2">
              Uptime: {systemMetrics.uptime}
            </p>
          </CardContent>
        </Card>
      </div>
    </div>
  );
});

SystemHealthMonitor.displayName = 'SystemHealthMonitor';

/**
 * User Management Component
 * Comprehensive user administration interface
 */
const UserManagement: React.FC = React.memo(() => {
  const [users, setUsers] = useState<UserActivity[]>([
    {
      userId: '1',
      username: 'sirwan',
      lastActivity: '2 minutes ago',
      actionsToday: 15,
      role: 'admin'
    },
    {
      userId: '2',
      username: 'developer1',
      lastActivity: '1 hour ago',
      actionsToday: 8,
      role: 'developer'
    },
    {
      userId: '3',
      username: 'developer2',
      lastActivity: '3 hours ago',
      actionsToday: 12,
      role: 'developer'
    }
  ]);

  const [searchTerm, setSearchTerm] = useState('');

  const filteredUsers = useMemo(() => {
    return users.filter(user => 
      user.username.toLowerCase().includes(searchTerm.toLowerCase()) ||
      user.role.toLowerCase().includes(searchTerm.toLowerCase())
    );
  }, [users, searchTerm]);

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-lg font-semibold">User Management</h3>
          <p className="text-sm text-muted-foreground">
            Manage platform users and permissions
          </p>
        </div>
        <div className="flex gap-2">
          <div className="relative">
            <Search className="absolute left-2 top-2.5 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="Search users..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pl-8"
            />
          </div>
          <Button>
            <Plus className="h-4 w-4 mr-2" />
            Add User
          </Button>
        </div>
      </div>

      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Username</TableHead>
                <TableHead>Role</TableHead>
                <TableHead>Last Activity</TableHead>
                <TableHead>Actions Today</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredUsers.map((user) => (
                <TableRow key={user.userId}>
                  <TableCell className="font-medium">{user.username}</TableCell>
                  <TableCell>
                    <Badge variant={user.role === 'admin' ? 'default' : 'secondary'}>
                      {user.role}
                    </Badge>
                  </TableCell>
                  <TableCell className="text-muted-foreground">
                    {user.lastActivity}
                  </TableCell>
                  <TableCell>{user.actionsToday}</TableCell>
                  <TableCell>
                    <Badge variant="success">
                      <CheckCircle className="h-3 w-3 mr-1" />
                      Active
                    </Badge>
                  </TableCell>
                  <TableCell>
                    <div className="flex gap-2">
                      <Button variant="outline" size="sm">
                        <Eye className="h-3 w-3 mr-1" />
                        View
                      </Button>
                      <Button variant="outline" size="sm">
                        <Settings className="h-3 w-3 mr-1" />
                        Edit
                      </Button>
                    </div>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
});

UserManagement.displayName = 'UserManagement';

/**
 * Service Health Dashboard
 * Monitor and manage all platform services
 */
const ServiceHealthDashboard: React.FC = React.memo(() => {
  const [services, setServices] = useState<ServiceHealth[]>([
    {
      name: 'API Gateway',
      status: 'healthy',
      uptime: '99.9%',
      responseTime: 120,
      errorRate: 0.1
    },
    {
      name: 'Database',
      status: 'healthy',
      uptime: '99.8%',
      responseTime: 45,
      errorRate: 0.2
    },
    {
      name: 'File Storage',
      status: 'warning',
      uptime: '98.5%',
      responseTime: 200,
      errorRate: 1.2
    },
    {
      name: 'Authentication',
      status: 'healthy',
      uptime: '99.9%',
      responseTime: 80,
      errorRate: 0.0
    }
  ]);

  const getStatusIcon = (status: ServiceHealth['status']) => {
    switch (status) {
      case 'healthy':
        return <CheckCircle className="h-4 w-4 text-green-500" />;
      case 'warning':
        return <AlertTriangle className="h-4 w-4 text-yellow-500" />;
      case 'error':
        return <XCircle className="h-4 w-4 text-red-500" />;
      default:
        return <AlertCircle className="h-4 w-4 text-gray-500" />;
    }
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <div>
          <h3 className="text-lg font-semibold">Service Health</h3>
          <p className="text-sm text-muted-foreground">
            Monitor platform services and infrastructure
          </p>
        </div>
        <Button variant="outline">
          <RefreshCw className="h-4 w-4 mr-2" />
          Refresh All
        </Button>
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        {services.map((service) => (
          <Card key={service.name}>
            <CardHeader>
              <CardTitle className="flex items-center justify-between">
                <span className="flex items-center gap-2">
                  {getStatusIcon(service.status)}
                  {service.name}
                </span>
                <Badge 
                  variant={
                    service.status === 'healthy' ? 'success' : 
                    service.status === 'warning' ? 'warning' : 'destructive'
                  }
                >
                  {service.status}
                </Badge>
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-3 gap-4 text-sm">
                <div>
                  <p className="text-muted-foreground">Uptime</p>
                  <p className="font-medium">{service.uptime}</p>
                </div>
                <div>
                  <p className="text-muted-foreground">Response</p>
                  <p className="font-medium">{service.responseTime}ms</p>
                </div>
                <div>
                  <p className="text-muted-foreground">Error Rate</p>
                  <p className="font-medium">{service.errorRate}%</p>
                </div>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
});

ServiceHealthDashboard.displayName = 'ServiceHealthDashboard';

/**
 * Main Admin Dashboard Component
 * Enterprise-grade administrative interface
 */
export const AdminDashboard: React.FC = () => {
  const { 
    // Keep other store functionality but not requests/fetchRequests 
    loading: storeLoading, 
    error: storeError
  } = useAppStore();

  // Local state for deployment requests from API
  const [deploymentRequests, setDeploymentRequests] = useState<DeploymentRequest[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  const [selectedRequest, setSelectedRequest] = useState<DeploymentRequest | null>(null);
  const [requestToReject, setRequestToReject] = useState<DeploymentRequest | null>(null);
  const [rejectReason, setRejectReason] = useState('');
  const [showRejectForm, setShowRejectForm] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [deploymentLogs, setDeploymentLogs] = useState<any[]>([]);
  const [selectedLogEntry, setSelectedLogEntry] = useState<any | null>(null);

  // Load deployment requests from API
  const fetchDeploymentRequests = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await getDeploymentRequests();
      setDeploymentRequests(response.requests);
    } catch (err) {
      console.error('Failed to fetch deployment requests:', err);
      setError('Failed to load deployment requests');
      setDeploymentRequests([]);
    } finally {
      setLoading(false);
    }
  }, []);

  // Fetch data on component mount
  useEffect(() => {
    fetchDeploymentRequests();
    loadDeploymentLogs();
  }, [fetchDeploymentRequests]);

  // Load deployment logs from backend only
  const loadDeploymentLogs = useCallback(async () => {
    try {
      // Only load real deployment logs - no mock data
      const existingLogs = localStorage.getItem('deployment-logs');
      if (existingLogs) {
        const logs = JSON.parse(existingLogs);
        // Filter out any mock logs that might exist
        const realLogs = logs.filter((log: any) => log.realDeployment === true);
        setDeploymentLogs(realLogs);
        // Update localStorage to only contain real logs
        localStorage.setItem('deployment-logs', JSON.stringify(realLogs));
      } else {
        // Start with empty logs - only real deployments will be added
        setDeploymentLogs([]);
        localStorage.setItem('deployment-logs', JSON.stringify([]));
      }
    } catch (error) {
      console.error('Failed to load deployment logs:', error);
      setDeploymentLogs([]);
    }
  }, []);

  // Compute derived metrics with useMemo for performance
  const metrics = useMemo(() => {
    const pendingRequests = deploymentRequests.filter(req => req.status === 'pending');
    const processingRequests = deploymentRequests.filter(req => req.status === 'approved');
    const completedRequests = deploymentRequests.filter(req => req.status === 'deployed');
    const failedRequests = deploymentRequests.filter(req => req.status === 'failed');

    return {
      pending: pendingRequests.length,
      processing: processingRequests.length,
      completed: completedRequests.length,
      failed: failedRequests.length,
      total: deploymentRequests.length,
      successRate: deploymentRequests.length > 0 ? 
        Math.round((completedRequests.length / deploymentRequests.length) * 100) : 0
    };
  }, [deploymentRequests]);

  // Optimized refresh handler
  const handleRefresh = useCallback(async () => {
    setRefreshing(true);
    try {
      await fetchDeploymentRequests();
    } finally {
      setRefreshing(false);
    }
  }, [fetchDeploymentRequests]);

  // Approval handler with error handling and deployment logging
  const handleApprove = useCallback(async (requestId: string) => {
    try {
      await approveDeploymentRequest(requestId, { action: 'approve' });
      
      // Find the approved request to create deployment log
      const approvedRequest = deploymentRequests.find(req => req.request_id === requestId);
      if (approvedRequest) {
        createDeploymentLog(approvedRequest);
      }
      
      // Refresh the requests list
      await fetchDeploymentRequests();
    } catch (error) {
      console.error('Failed to approve request:', error);
    }
  }, [deploymentRequests, fetchDeploymentRequests]);

  // Create deployment log entry when request is approved
  const createDeploymentLog = useCallback(async (request: DeploymentRequest) => {
    const logId = `LOG-${Date.now()}`;
    const startTime = new Date().toISOString();
    
    // Create initial log entry
    const newLog = {
      id: logId,
      requestId: request.request_id,
      serviceName: request.service_name || request.name || 'Unknown Service',
      type: request.template_name || `${request.resource_type.toUpperCase()} Template`,
      status: 'IN_PROGRESS',
      startTime: startTime,
      endTime: null,
      duration: '0s',
      realDeployment: true, // Mark as real deployment
      steps: [
        { 
          step: 1, 
          name: 'Validation', 
          status: 'IN_PROGRESS', 
          message: 'Validating configuration...', 
          timestamp: startTime 
        },
        { 
          step: 2, 
          name: 'Terraform Init', 
          status: 'PENDING', 
          message: 'Waiting for validation to complete', 
          timestamp: null 
        },
        { 
          step: 3, 
          name: 'Terraform Plan', 
          status: 'PENDING', 
          message: 'Waiting for initialization', 
          timestamp: null 
        },
        { 
          step: 4, 
          name: 'Terraform Apply', 
          status: 'PENDING', 
          message: 'Waiting for plan generation', 
          timestamp: null 
        },
        { 
          step: 5, 
          name: 'Resource Verification', 
          status: 'PENDING', 
          message: 'Waiting for deployment', 
          timestamp: null 
        }
      ],
      logs: [
        `[${new Date().toLocaleString()}] Deployment initiated for: ${request.service_name || request.name || 'Unknown'}`,
        `[${new Date().toLocaleString()}] Starting validation process...`
      ]
    };

    // Add to deployment logs
    setDeploymentLogs(prev => {
      const updated = [newLog, ...prev];
      localStorage.setItem('deployment-logs', JSON.stringify(updated));
      return updated;
    });

    // **REAL DEPLOYMENT**: Send to backend for actual processing
    try {
      // Call your FastAPI backend to start real deployment
      const response = await fetch('http://localhost:8001/api/jobs/create', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          job_id: logId,
          action: 'CREATE',
          resource_type: request.resource_type?.toUpperCase(),
          name: request.service_name || request.name,
          environment: request.environment || 'dev',
          region: request.region || 'us-east-1',
          config: request.config,
        }),
      });

      if (response.ok) {
        const jobResult = await response.json();
        console.log('Real deployment job created:', jobResult);
        
        // Start polling for real job status
        pollJobStatus(logId, jobResult.job_id);
      } else {
        const errorText = await response.text();
        throw new Error(`Failed to create deployment job: ${response.status} ${errorText}`);
      }
    } catch (error) {
      console.error('Failed to start real deployment:', error);
      
      // Update log to show error state instead of falling back to simulation
      setDeploymentLogs(prev => {
        const updated = prev.map(log => {
          if (log.id === logId) {
            return {
              ...log,
              status: 'FAILED',
              errorMessage: `Backend deployment failed: ${error}`,
              endTime: new Date().toISOString(),
              duration: calculateDuration(log.startTime, new Date().toISOString())
            };
          }
          return log;
        });
        localStorage.setItem('deployment-logs', JSON.stringify(updated));
        return updated;
      });
    }
  }, []);

  // Poll real job status from backend
  const pollJobStatus = useCallback(async (logId: string, jobId: string) => {
    const pollInterval = setInterval(async () => {
      try {
        const response = await fetch(`http://localhost:8001/api/jobs/${jobId}/status`);
        if (response.ok) {
          const jobStatus = await response.json();
          
          // Update log with real job progress
          setDeploymentLogs(prev => {
            const updated = prev.map(log => {
              if (log.id === logId) {
                return {
                  ...log,
                  status: mapJobStatusToLogStatus(jobStatus.status),
                  endTime: jobStatus.completed_at,
                  duration: jobStatus.completed_at ? 
                    calculateDuration(log.startTime, jobStatus.completed_at) : log.duration,
                  steps: mapJobStepsToLogSteps(jobStatus.progress?.steps || []),
                  logs: jobStatus.logs?.map((l: any) => 
                    `[${new Date(l.timestamp).toLocaleString()}] ${l.message}`
                  ) || log.logs,
                  terraformOutput: jobStatus.terraform_output,
                  errorMessage: jobStatus.error_message
                };
              }
              return log;
            });
            localStorage.setItem('deployment-logs', JSON.stringify(updated));
            return updated;
          });

          // Stop polling if job is complete
          if (['COMPLETED', 'FAILED', 'CANCELLED'].includes(jobStatus.status)) {
            clearInterval(pollInterval);
          }
        }
      } catch (error) {
        console.error('Failed to poll job status:', error);
        clearInterval(pollInterval);
      }
    }, 5000); // Poll every 5 seconds

    // Clear interval after 30 minutes to prevent infinite polling
    setTimeout(() => clearInterval(pollInterval), 30 * 60 * 1000);
  }, []);

  // Helper functions for mapping backend data to frontend format
  const mapJobStatusToLogStatus = (jobStatus: string) => {
    switch (jobStatus) {
      case 'COMPLETED': return 'SUCCESS';
      case 'FAILED': return 'FAILED';
      case 'RUNNING': case 'QUEUED': return 'IN_PROGRESS';
      default: return 'IN_PROGRESS';
    }
  };

  const mapJobStepsToLogSteps = (jobSteps: any[]) => {
    return jobSteps.map((step, index) => ({
      step: index + 1,
      name: step.name,
      status: step.status,
      message: step.message,
      timestamp: step.timestamp
    }));
  };

  const calculateDuration = (startTime: string, endTime: string) => {
    const start = new Date(startTime).getTime();
    const end = new Date(endTime).getTime();
    const seconds = Math.floor((end - start) / 1000);
    return `${seconds}s`;
  };

  // Rejection handler
  const handleReject = useCallback((requestId: string) => {
    const request = deploymentRequests.find(req => req.request_id === requestId);
    setRequestToReject(request || null);
    setShowRejectForm(true);
  }, [deploymentRequests]);

  // Submit rejection with validation
  const submitRejection = useCallback(async () => {
    if (requestToReject && rejectReason.trim()) {
      try {
        await approveDeploymentRequest(requestToReject.request_id, { 
          action: 'reject', 
          reason: rejectReason 
        });
        setShowRejectForm(false);
        setRequestToReject(null);
        setRejectReason('');
        // Refresh the requests list
        await fetchDeploymentRequests();
      } catch (error) {
        console.error('Failed to reject request:', error);
      }
    }
  }, [requestToReject, rejectReason, fetchDeploymentRequests]);

  // Status badge renderer
  const getStatusBadge = useCallback((status: string) => {
    const variants: Record<string, any> = {
      pending: { variant: 'warning', label: 'Pending Review' },
      approved: { variant: 'default', label: 'Approved' },
      rejected: { variant: 'destructive', label: 'Rejected' },
      deployed: { variant: 'success', label: 'Deployed' },
      failed: { variant: 'destructive', label: 'Failed' },
      // Legacy status mapping for backward compatibility
      PENDING: { variant: 'warning', label: 'Pending Review' },
      APPROVED: { variant: 'default', label: 'Approved' },
      REJECTED: { variant: 'destructive', label: 'Rejected' },
      PROCESSING: { variant: 'default', label: 'Processing' },
      COMPLETED: { variant: 'success', label: 'Completed' },
      FAILED: { variant: 'destructive', label: 'Failed' }
    };
    
    const config = variants[status] || { variant: 'secondary', label: status };
    return <Badge variant={config.variant}>{config.label}</Badge>;
  }, []);

  // Date formatter
  const formatDate = useCallback((dateString: string) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }, []);

  return (
    <div className="space-y-6 p-6">
      {/* Professional Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">
            Platform Administration
          </h1>
          <p className="text-muted-foreground">
            Infrastructure management and oversight
          </p>
        </div>
        <div className="flex gap-2">
          <Button 
            variant="outline" 
            onClick={handleRefresh}
            disabled={refreshing}
            aria-label="Refresh dashboard data"
          >
            <RefreshCw className={`h-4 w-4 mr-2 ${refreshing ? 'animate-spin' : ''}`} />
            Refresh
          </Button>
          <Button>
            <BarChart3 className="h-4 w-4 mr-2" />
            Analytics
          </Button>
        </div>
      </div>

      {/* Key Metrics Overview */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <AdminMetricCard
          title="Pending Approvals"
          value={metrics.pending}
          description="Awaiting admin review"
          icon={<Clock className="h-4 w-4" />}
          variant="warning"
        />
        <AdminMetricCard
          title="Active Deployments"
          value={metrics.processing}
          description="Currently deploying"
          icon={<Zap className="h-4 w-4" />}
          variant="info"
        />
        <AdminMetricCard
          title="Running Services"
          value={metrics.completed}
          description="Successfully deployed"
          icon={<CheckCircle className="h-4 w-4" />}
          variant="success"
        />
        <AdminMetricCard
          title="Success Rate"
          value={`${metrics.successRate}%`}
          description="Deployment success rate"
          icon={<TrendingUp className="h-4 w-4" />}
          variant={metrics.successRate > 90 ? 'success' : 'warning'}
          trend={{
            value: 5.2,
            isPositive: true
          }}
        />
      </div>

      {/* Professional Tabbed Interface */}
      <Tabs defaultValue="overview" className="space-y-4">
        <TabsList className="grid w-full grid-cols-7">
          <TabsTrigger value="overview" className="flex items-center gap-2">
            <Activity className="h-4 w-4" />
            Overview
          </TabsTrigger>
          <TabsTrigger value="requests" className="flex items-center gap-2">
            <FileText className="h-4 w-4" />
            Requests
          </TabsTrigger>
          <TabsTrigger value="logs" className="flex items-center gap-2">
            <BarChart3 className="h-4 w-4" />
            Logs
          </TabsTrigger>
          <TabsTrigger value="services" className="flex items-center gap-2">
            <Server className="h-4 w-4" />
            Services
          </TabsTrigger>
          <TabsTrigger value="users" className="flex items-center gap-2">
            <Users className="h-4 w-4" />
            Users
          </TabsTrigger>
          <TabsTrigger value="system" className="flex items-center gap-2">
            <Settings className="h-4 w-4" />
            System
          </TabsTrigger>
          <TabsTrigger value="security" className="flex items-center gap-2">
            <Shield className="h-4 w-4" />
            Security
          </TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="space-y-4">
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-2">
            <Card className="cursor-pointer hover:shadow-md transition-all duration-200 hover:scale-105">
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <BarChart3 className="h-5 w-5" />
                  Platform Analytics
                </CardTitle>
                <CardDescription>
                  Usage metrics and performance insights
                </CardDescription>
              </CardHeader>
            </Card>

            <Card className="cursor-pointer hover:shadow-md transition-all duration-200 hover:scale-105">
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Shield className="h-5 w-5" />
                  Security Center
                </CardTitle>
                <CardDescription>
                  Access controls and audit logs
                </CardDescription>
              </CardHeader>
            </Card>
          </div>

          {/* Quick Actions for Pending Approvals */}
          {metrics.pending > 0 && (
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <AlertTriangle className="h-5 w-5 text-yellow-500" />
                  Urgent: Pending Approvals ({metrics.pending})
                </CardTitle>
                <CardDescription>
                  Deployment requests requiring immediate attention
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-2">
                  {deploymentRequests
                    .filter(req => req.status === 'pending')
                    .slice(0, 3)
                    .map((request) => (
                      <div key={request.request_id} className="flex items-center justify-between p-3 border rounded-lg">
                        <div>
                          <p className="font-medium">
                            {request.service_name || request.name || 'Unknown Service'}
                          </p>
                          <p className="text-sm text-muted-foreground">
                            Requested by developer-user • {formatDate(request.created_at)}
                          </p>
                        </div>
                        <div className="flex gap-2">
                          <Button 
                            size="sm" 
                            onClick={() => handleApprove(request.request_id)}
                            disabled={loading}
                          >
                            <CheckSquare className="h-3 w-3 mr-1" />
                            Approve
                          </Button>
                          <Button 
                            variant="destructive" 
                            size="sm"
                            onClick={(e) => {
                              e.stopPropagation();
                              handleReject(request.request_id);
                            }}
                            disabled={loading}
                          >
                            <XCircle className="h-3 w-3 mr-1" />
                            Reject
                          </Button>
                        </div>
                      </div>
                    ))}
                </div>
              </CardContent>
            </Card>
          )}
        </TabsContent>

        <TabsContent value="requests" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Deployment Requests Management</CardTitle>
              <CardDescription>
                Review, approve, and monitor all infrastructure deployment requests
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
              ) : deploymentRequests.length === 0 ? (
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
                        <TableHead>Actions</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {deploymentRequests.slice(0, 20).map((request) => (
                        <TableRow key={request.request_id}>
                          <TableCell className="font-medium">
                            {request.service_name || request.name || 'Unknown'}
                          </TableCell>
                          <TableCell>{'developer-user'}</TableCell>
                          <TableCell>
                            <Badge variant="outline">
                              {request.template_name}
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
                              {request.status === 'pending' && (
                                <>
                                  <Button 
                                    size="sm"
                                    onClick={() => handleApprove(request.request_id)}
                                    disabled={loading}
                                  >
                                    <CheckSquare className="h-3 w-3 mr-1" />
                                    Approve
                                  </Button>
                                  <Button 
                                    variant="destructive" 
                                    size="sm"
                                    onClick={(e) => {
                                      e.stopPropagation();
                                      handleReject(request.request_id);
                                    }}
                                    disabled={loading}
                                  >
                                    <XCircle className="h-3 w-3 mr-1" />
                                    Reject
                                  </Button>
                                </>
                              )}
                              <Button variant="outline" size="sm" onClick={() => setSelectedRequest(request)}>
                                <Eye className="h-3 w-3 mr-1" />
                                Details
                              </Button>
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
        </TabsContent>

        <TabsContent value="logs" className="space-y-4">
          <Card>
            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-6">
              <div>
                <CardTitle className="text-2xl font-bold">Deployment Logs & Tracking</CardTitle>
                <CardDescription>
                  Track deployment progress, view logs, and troubleshoot issues
                </CardDescription>
              </div>
              <div className="flex gap-2">
                <Button 
                  variant="outline" 
                  size="sm"
                  onClick={loadDeploymentLogs}
                >
                  <RefreshCw className="h-4 w-4 mr-2" />
                  Refresh
                </Button>
                <Button 
                  variant="outline" 
                  size="sm"
                  onClick={() => {
                    const logs = deploymentLogs.map(log => JSON.stringify(log, null, 2)).join('\n\n');
                    const blob = new Blob([logs], { type: 'text/plain' });
                    const url = URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = `deployment-logs-${new Date().toISOString().split('T')[0]}.txt`;
                    a.click();
                    URL.revokeObjectURL(url);
                  }}
                >
                  <Download className="h-4 w-4 mr-2" />
                  Export
                </Button>
              </div>
            </CardHeader>
            <CardContent>
              {deploymentLogs.length === 0 ? (
                <div className="text-center py-8 bg-gray-50 rounded-lg">
                  <BarChart3 className="h-12 w-12 text-gray-400 mx-auto mb-4" />
                  <p className="text-gray-500">No deployment logs available</p>
                  <p className="text-sm text-gray-400 mt-2">Logs will appear here after approving requests</p>
                </div>
              ) : (
                <div className="space-y-4">
                  {/* Summary Cards */}
                  <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
                    <Card>
                      <CardContent className="p-4">
                        <div className="flex items-center">
                          <CheckCircle className="h-8 w-8 text-green-500" />
                          <div className="ml-4">
                            <p className="text-sm font-medium text-gray-600">Successful</p>
                            <p className="text-2xl font-bold text-green-600">
                              {deploymentLogs.filter(log => log.status === 'SUCCESS').length}
                            </p>
                          </div>
                        </div>
                      </CardContent>
                    </Card>
                    
                    <Card>
                      <CardContent className="p-4">
                        <div className="flex items-center">
                          <XCircle className="h-8 w-8 text-red-500" />
                          <div className="ml-4">
                            <p className="text-sm font-medium text-gray-600">Failed</p>
                            <p className="text-2xl font-bold text-red-600">
                              {deploymentLogs.filter(log => log.status === 'FAILED').length}
                            </p>
                          </div>
                        </div>
                      </CardContent>
                    </Card>
                    
                    <Card>
                      <CardContent className="p-4">
                        <div className="flex items-center">
                          <Clock className="h-8 w-8 text-blue-500" />
                          <div className="ml-4">
                            <p className="text-sm font-medium text-gray-600">In Progress</p>
                            <p className="text-2xl font-bold text-blue-600">
                              {deploymentLogs.filter(log => log.status === 'IN_PROGRESS').length}
                            </p>
                          </div>
                        </div>
                      </CardContent>
                    </Card>
                    
                    <Card>
                      <CardContent className="p-4">
                        <div className="flex items-center">
                          <BarChart3 className="h-8 w-8 text-purple-500" />
                          <div className="ml-4">
                            <p className="text-sm font-medium text-gray-600">Total</p>
                            <p className="text-2xl font-bold text-purple-600">{deploymentLogs.length}</p>
                          </div>
                        </div>
                      </CardContent>
                    </Card>
                  </div>

                  {/* Deployment Logs Table */}
                  <div className="border rounded-lg">
                    <Table>
                      <TableHeader>
                        <TableRow>
                          <TableHead>Service Name</TableHead>
                          <TableHead>Type</TableHead>
                          <TableHead>Status</TableHead>
                          <TableHead>Duration</TableHead>
                          <TableHead>Started</TableHead>
                          <TableHead>Actions</TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {deploymentLogs.slice(0, 10).map((log) => (
                          <TableRow key={log.id}>
                            <TableCell className="font-medium">{log.serviceName}</TableCell>
                            <TableCell>
                              <Badge variant="outline">
                                {log.type.replace('_', ' ')}
                              </Badge>
                            </TableCell>
                            <TableCell>
                              <Badge 
                                variant={log.status === 'SUCCESS' ? 'default' : log.status === 'FAILED' ? 'destructive' : 'secondary'}
                              >
                                {log.status === 'SUCCESS' && <CheckCircle className="h-3 w-3 mr-1" />}
                                {log.status === 'FAILED' && <XCircle className="h-3 w-3 mr-1" />}
                                {log.status === 'IN_PROGRESS' && <Clock className="h-3 w-3 mr-1" />}
                                {log.status}
                              </Badge>
                            </TableCell>
                            <TableCell className="text-muted-foreground">{log.duration}</TableCell>
                            <TableCell className="text-muted-foreground">
                              {new Date(log.startTime).toLocaleString()}
                            </TableCell>
                            <TableCell>
                              <Button 
                                variant="outline" 
                                size="sm"
                                onClick={() => setSelectedLogEntry(log)}
                              >
                                <Eye className="h-3 w-3 mr-1" />
                                View Details
                              </Button>
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="services" className="space-y-4">
          <Suspense fallback={<div>Loading services...</div>}>
            <ServiceHealthDashboard />
          </Suspense>
        </TabsContent>

        <TabsContent value="users" className="space-y-4">
          <Suspense fallback={<div>Loading users...</div>}>
            <UserManagement />
          </Suspense>
        </TabsContent>

        <TabsContent value="system" className="space-y-4">
          <Suspense fallback={<div>Loading system metrics...</div>}>
            <SystemHealthMonitor />
          </Suspense>
        </TabsContent>

        <TabsContent value="security" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Lock className="h-5 w-5" />
                Security & Compliance
              </CardTitle>
              <CardDescription>
                Platform security monitoring and access controls
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid gap-4 md:grid-cols-2">
                <Card>
                  <CardHeader>
                    <CardTitle className="text-lg">Access Logs</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <p className="text-sm text-muted-foreground mb-4">
                      Recent authentication and authorization events
                    </p>
                    <Button variant="outline" className="w-full">
                      <FileText className="h-4 w-4 mr-2" />
                      View Security Logs
                    </Button>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader>
                    <CardTitle className="text-lg">Permission Management</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <p className="text-sm text-muted-foreground mb-4">
                      Configure user roles and access permissions
                    </p>
                    <Button variant="outline" className="w-full">
                      <UserCheck className="h-4 w-4 mr-2" />
                      Manage Permissions
                    </Button>
                  </CardContent>
                </Card>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      {/* Professional Rejection Modal */}
      {showRejectForm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center p-4 z-50">
          <Card className="w-full max-w-md">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <AlertTriangle className="h-5 w-5 text-yellow-500" />
                Reject Deployment Request
              </CardTitle>
              <CardDescription>
                Please provide a detailed reason for rejecting this deployment request
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div>
                <Label htmlFor="reason">Rejection Reason *</Label>
                <Input
                  id="reason"
                  value={rejectReason}
                  onChange={(e) => setRejectReason(e.target.value)}
                  placeholder="e.g., Security concerns, insufficient resources, policy violation..."
                  className="mt-1"
                />
              </div>
              <div className="flex gap-2 justify-end">
                <Button 
                  variant="outline" 
                  onClick={() => {
                    setShowRejectForm(false);
                    setRequestToReject(null);
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
                  <XCircle className="h-4 w-4 mr-2" />
                  Reject Request
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      )}

      {/* Request Details Modal */}
      {selectedRequest && !showRejectForm && (() => {
        // Type assertion for localStorage-based requests
        const request = selectedRequest as any;
        return (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg p-6 max-w-4xl w-full max-h-screen overflow-y-auto">
            <div className="flex justify-between items-start mb-6">
              <div>
                <h2 className="text-2xl font-bold text-gray-900">Request Details</h2>
                <p className="text-gray-600">ID: {request.request_id}</p>
              </div>
              <Button 
                variant="outline" 
                size="sm"
                onClick={() => setSelectedRequest(null)}
              >
                <XCircle className="h-4 w-4" />
              </Button>
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Basic Information */}
              <Card>
                <CardHeader>
                  <CardTitle className="text-lg">Basic Information</CardTitle>
                </CardHeader>
                <CardContent className="space-y-3">
                  <div>
                    <span className="font-semibold">Service Name:</span> {request.configuration?.bucketName || request.title || 'Unknown'}
                  </div>
                  <div>
                    <span className="font-semibold">Template:</span> 
                    <Badge variant="outline" className="ml-2">
                      {request.request_type === 's3_bucket' ? 'Sirwan Test S3' : 'Unknown Template'}
                    </Badge>
                  </div>
                  <div>
                    <span className="font-semibold">Type:</span> 
                    <Badge variant="outline" className="ml-2">
                      {request.request_type === 's3_bucket' ? 'S3 BUCKET' : (request.request_type || 'Unknown').replace('_', ' ').toUpperCase()}
                    </Badge>
                  </div>
                  <div>
                    <span className="font-semibold">Status:</span> 
                    <Badge variant="outline" className="ml-2">
                      {request.status?.toUpperCase() || 'PENDING'}
                    </Badge>
                  </div>
                  <div>
                    <span className="font-semibold">Requested By:</span> {request.requested_by || request.requester || 'Unknown'}
                  </div>
                  <div>
                    <span className="font-semibold">Estimated Cost:</span> ${request.estimated_cost || 0}/month
                  </div>
                  <div>
                    <span className="font-semibold">Created:</span> {request.created_at ? new Date(request.created_at).toLocaleString() : 'Unknown'}
                  </div>
                </CardContent>
              </Card>

              {/* Configuration Details */}
              <Card>
                <CardHeader>
                  <CardTitle className="text-lg">Configuration</CardTitle>
                </CardHeader>
                <CardContent>
                  {request.configuration && (
                    <div className="space-y-3">
                      {request.request_type === 's3_bucket' && (
                        <>
                          <div>
                            <span className="font-semibold">Bucket Name:</span> {request.configuration.bucketName}
                          </div>
                          <div>
                            <span className="font-semibold">Environment:</span> {request.configuration.environment}
                          </div>
                          <div>
                            <span className="font-semibold">Versioning:</span> {request.configuration.versioning ? 'Enabled' : 'Disabled'}
                          </div>
                          <div>
                            <span className="font-semibold">Encryption:</span> {request.configuration.encryption ? 'Enabled' : 'Disabled'}
                          </div>
                          <div>
                            <span className="font-semibold">Public Access:</span> {request.configuration.publicAccess ? 'Enabled' : 'Disabled'}
                          </div>
                          {request.configuration.ec2Enabled && (
                            <>
                              <div>
                                <span className="font-semibold">EC2 Integration:</span> Enabled
                              </div>
                              <div>
                                <span className="font-semibold">Instance Type:</span> {request.configuration.ec2InstanceType}
                              </div>
                              <div>
                                <span className="font-semibold">Key Pair:</span> {request.configuration.ec2KeyPair}
                              </div>
                            </>
                          )}
                        </>
                      )}
                    </div>
                  )}
                  
                  {/* Raw Configuration */}
                  <div className="mt-4">
                    <span className="font-semibold block mb-2">Raw Configuration:</span>
                    <pre className="bg-gray-100 p-3 rounded text-xs overflow-x-auto">
                      {JSON.stringify(request.configuration || {}, null, 2)}
                    </pre>
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* Description */}
            {request.description && (
              <Card className="mt-6">
                <CardHeader>
                  <CardTitle className="text-lg">Description</CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-gray-700">{request.description}</p>
                </CardContent>
              </Card>
            )}

            {/* Action Buttons */}
            <div className="flex justify-end gap-3 mt-6">
              {request.status === 'pending' && (
                <>
                  <Button 
                    variant="destructive"
                    onClick={() => {
                      setShowRejectForm(true);
                      // Keep the modal open but show reject form
                    }}
                  >
                    <XCircle className="h-4 w-4 mr-2" />
                    Reject
                  </Button>
                  <Button 
                    onClick={() => {
                      handleApprove(request.request_id);
                      setSelectedRequest(null);
                    }}
                  >
                    <CheckSquare className="h-4 w-4 mr-2" />
                    Approve & Deploy
                  </Button>
                </>
              )}
              <Button 
                variant="outline"
                onClick={() => setSelectedRequest(null)}
              >
                Close
              </Button>
            </div>
          </div>
        </div>
        );
      })()}

      {/* Deployment Log Details Modal */}
      {selectedLogEntry && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg p-6 max-w-6xl w-full max-h-screen overflow-y-auto">
            <div className="flex justify-between items-start mb-6">
              <div>
                <h2 className="text-2xl font-bold text-gray-900">Deployment Log Details</h2>
                <p className="text-gray-600">
                  {selectedLogEntry.serviceName} - {selectedLogEntry.id}
                </p>
              </div>
              <Button 
                variant="outline" 
                size="sm"
                onClick={() => setSelectedLogEntry(null)}
              >
                <XCircle className="h-4 w-4" />
              </Button>
            </div>
            
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Summary Information */}
              <Card>
                <CardHeader>
                  <CardTitle className="text-lg">Deployment Summary</CardTitle>
                </CardHeader>
                <CardContent className="space-y-3">
                  <div>
                    <span className="font-semibold">Service Name:</span> {selectedLogEntry.serviceName}
                  </div>
                  <div>
                    <span className="font-semibold">Type:</span> 
                    <Badge variant="outline" className="ml-2">
                      {selectedLogEntry.type.replace('_', ' ')}
                    </Badge>
                  </div>
                  <div>
                    <span className="font-semibold">Status:</span> 
                    <Badge 
                      variant={selectedLogEntry.status === 'SUCCESS' ? 'default' : selectedLogEntry.status === 'FAILED' ? 'destructive' : 'secondary'}
                      className="ml-2"
                    >
                      {selectedLogEntry.status === 'SUCCESS' && <CheckCircle className="h-3 w-3 mr-1" />}
                      {selectedLogEntry.status === 'FAILED' && <XCircle className="h-3 w-3 mr-1" />}
                      {selectedLogEntry.status === 'IN_PROGRESS' && <Clock className="h-3 w-3 mr-1" />}
                      {selectedLogEntry.status}
                    </Badge>
                  </div>
                  <div>
                    <span className="font-semibold">Duration:</span> {selectedLogEntry.duration}
                  </div>
                  <div>
                    <span className="font-semibold">Started:</span> {new Date(selectedLogEntry.startTime).toLocaleString()}
                  </div>
                  <div>
                    <span className="font-semibold">Completed:</span> {selectedLogEntry.endTime ? new Date(selectedLogEntry.endTime).toLocaleString() : 'In Progress'}
                  </div>
                  {selectedLogEntry.errorMessage && (
                    <div>
                      <span className="font-semibold text-red-600">Error:</span> 
                      <p className="text-red-600 text-sm mt-1">{selectedLogEntry.errorMessage}</p>
                    </div>
                  )}
                </CardContent>
              </Card>

              {/* Deployment Steps */}
              <Card>
                <CardHeader>
                  <CardTitle className="text-lg">Deployment Steps</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-3">
                    {selectedLogEntry.steps?.map((step: any, index: number) => (
                      <div key={index} className="flex items-start space-x-3 p-3 rounded-lg bg-gray-50">
                        <div className="flex-shrink-0">
                          {step.status === 'COMPLETED' && <CheckCircle className="h-5 w-5 text-green-500" />}
                          {step.status === 'FAILED' && <XCircle className="h-5 w-5 text-red-500" />}
                          {step.status === 'IN_PROGRESS' && <Clock className="h-5 w-5 text-blue-500 animate-spin" />}
                          {step.status === 'PENDING' && <Clock className="h-5 w-5 text-gray-400" />}
                        </div>
                        <div className="flex-grow">
                          <div className="flex items-center justify-between">
                            <h4 className="font-medium">{step.name}</h4>
                            <span className="text-xs text-gray-500">
                              {new Date(step.timestamp).toLocaleTimeString()}
                            </span>
                          </div>
                          <p className="text-sm text-gray-600 mt-1">{step.message}</p>
                        </div>
                      </div>
                    ))}
                  </div>
                </CardContent>
              </Card>
            </div>

            {/* Terraform Output */}
            {selectedLogEntry.terraformOutput && (
              <Card className="mt-6">
                <CardHeader>
                  <CardTitle className="text-lg">Terraform Output</CardTitle>
                </CardHeader>
                <CardContent>
                  <pre className="bg-gray-100 p-4 rounded text-xs overflow-x-auto">
                    {JSON.stringify(selectedLogEntry.terraformOutput, null, 2)}
                  </pre>
                </CardContent>
              </Card>
            )}

            {/* Raw Logs */}
            <Card className="mt-6">
              <CardHeader>
                <CardTitle className="text-lg">Raw Deployment Logs</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="bg-black text-green-400 p-4 rounded font-mono text-sm max-h-96 overflow-y-auto">
                  {selectedLogEntry.logs?.map((log: string, index: number) => (
                    <div key={index} className="mb-1">
                      {log}
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>

            {/* API Documentation Link */}
            <div className="flex justify-between items-center mt-6 p-4 bg-blue-50 rounded-lg">
              <div>
                <h4 className="font-semibold text-blue-900">Need more details?</h4>
                <p className="text-sm text-blue-700">Check the API documentation for troubleshooting guides</p>
              </div>
              <Button 
                variant="outline"
                onClick={() => window.open('/api/docs', '_blank')}
              >
                <Globe className="h-4 w-4 mr-2" />
                View API Docs
              </Button>
            </div>

            {/* Action Buttons */}
            <div className="flex justify-end gap-3 mt-6">
              {selectedLogEntry.status === 'FAILED' && (
                <Button 
                  onClick={() => {
                    // In a real app, this would retry the deployment
                    alert('Retry deployment functionality would be implemented here');
                  }}
                >
                  <RefreshCw className="h-4 w-4 mr-2" />
                  Retry Deployment
                </Button>
              )}
              <Button 
                variant="outline"
                onClick={() => {
                  const logData = JSON.stringify(selectedLogEntry, null, 2);
                  const blob = new Blob([logData], { type: 'application/json' });
                  const url = URL.createObjectURL(blob);
                  const a = document.createElement('a');
                  a.href = url;
                  a.download = `deployment-log-${selectedLogEntry.id}.json`;
                  a.click();
                  URL.revokeObjectURL(url);
                }}
              >
                <Download className="h-4 w-4 mr-2" />
                Download Log
              </Button>
              <Button 
                variant="outline"
                onClick={() => setSelectedLogEntry(null)}
              >
                Close
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
