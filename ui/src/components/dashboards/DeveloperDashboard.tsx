/**
 * Professional Developer Dashboard - Clean Architecture Implementation
 * 
 * A comprehensive, enterprise-grade dashboard following modern React patterns:
 * - TypeScript with strict typing
 * - Component composition and reusability
 * - Performance optimization with useMemo/useCallback
 * - Accessibility (WCAG) compliance
 * - Error boundaries and loading states
 * - Clean Architecture principles
 * 
 * @author Senior Frontend Developer
 * @version 2.0.0
 */

import React, { useEffect, useState, useCallback, useMemo, Suspense } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { 
  Activity, 
  Server, 
  Database, 
  Globe, 
  Code, 
  Settings, 
  RefreshCw,
  Plus,
  TrendingUp,
  Clock,
  CheckCircle,
  XCircle,
  AlertCircle,
  Eye,
  Download
} from 'lucide-react';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
import { Button } from '../ui/button';
import { Badge } from '../ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../ui/tabs';
import { useAppStore } from '../../store/appStore';
import { apiClient } from '../../services/apiClient';

// Types for better TypeScript support
interface MetricCardProps {
  title: string;
  value: string | number;
  description: string;
  icon: React.ReactNode;
  variant: 'success' | 'warning' | 'error' | 'info';
}

interface DashboardMetrics {
  totalServices: number;
  runningServices: number;
  pendingDeployments: number;
  failedServices: number;
  totalRequests: number;
  recentJobs: any[];
  healthScore: number;
}

interface TemplateConfig {
  id: string;
  name: string;
  description: string;
  icon: React.ReactNode;
  features: string[];
  cost: string;
  runtime: string;
}

// Loading component
const LoadingSpinner: React.FC = () => (
  <div className="flex h-96 items-center justify-center" role="status" aria-label="Loading">
    <div className="text-center">
      <RefreshCw className="mx-auto h-8 w-8 animate-spin text-muted-foreground" />
      <p className="mt-2 text-sm text-muted-foreground">Loading dashboard...</p>
    </div>
  </div>
);

// Error boundary component
const ErrorDisplay: React.FC<{ error: string }> = ({ error }) => (
  <Card className="border-destructive bg-destructive/10">
    <CardContent className="pt-6">
      <div className="flex items-center gap-2 text-destructive">
        <AlertCircle className="h-4 w-4" />
        <p className="text-sm font-medium">{error}</p>
      </div>
    </CardContent>
  </Card>
);

/**
 * Reusable metric card component with accessibility support
 */
const MetricCard: React.FC<MetricCardProps> = ({ title, value, description, icon, variant }) => {
  const variantStyles = {
    success: 'text-green-600 bg-green-50',
    warning: 'text-yellow-600 bg-yellow-50',
    error: 'text-red-600 bg-red-50',
    info: 'text-blue-600 bg-blue-50'
  };

  return (
    <Card role="region" aria-labelledby={`metric-${title.replace(/\\s+/g, '-').toLowerCase()}`}>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle 
          className="text-sm font-medium" 
          id={`metric-${title.replace(/\\s+/g, '-').toLowerCase()}`}
        >
          {title}
        </CardTitle>
        <div className={`rounded-full p-2 ${variantStyles[variant]}`} aria-hidden="true">
          {icon}
        </div>
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold" aria-describedby={`desc-${title.replace(/\\s+/g, '-').toLowerCase()}`}>
          {value}
        </div>
        <p 
          className="text-xs text-muted-foreground" 
          id={`desc-${title.replace(/\\s+/g, '-').toLowerCase()}`}
        >
          {description}
        </p>
      </CardContent>
    </Card>
  );
};

/**
 * Template Gallery Component
 */
const TemplateGallery: React.FC = () => {
  const navigate = useNavigate();
  const [deployingTemplate, setDeployingTemplate] = useState<string | null>(null);

  const templates: TemplateConfig[] = [
    {
      id: 'web-app-simple',
      name: 'Web Application',
      description: 'Full-stack web app with S3, CloudFront, EC2, and optional RDS',
      icon: <Globe className="h-6 w-6" />,
      features: ['Static hosting', 'CDN', 'Backend server', 'Database'],
      cost: '$0-15/month',
      runtime: 'Node.js, Python, Java'
    },
    {
      id: 'api-simple',
      name: 'API Service',
      description: 'RESTful API service with auto-scaling and monitoring',
      icon: <Server className="h-6 w-6" />,
      features: ['Auto-scaling', 'Load balancing', 'Monitoring', 'SSL'],
      cost: '$0-10/month',
      runtime: 'Node.js, Python, Go, Java'
    },
    {
      id: 'sirwan-test',
      name: 'Sirwan Test',
      description: 'S3 bucket with advanced configuration and monitoring',
      icon: <Database className="h-6 w-6" />,
      features: ['Versioning', 'CORS', 'Lifecycle', 'Monitoring'],
      cost: '$0-5/month',
      runtime: 'Storage only'
    }
  ];

  const handleDeploy = async (templateId: string) => {
    // For sirwan-test template, navigate to the detailed form
    if (templateId === 'sirwan-test') {
      navigate('/sirwan-test-s3');
      return;
    }

    // For other templates, deploy directly with basic configuration
    setDeployingTemplate(templateId);
    
    try {
      const templateConfig = templates.find(t => t.id === templateId);
      
      const response = await apiClient.createInfrastructure({
        resource_type: templateId === 'web-app-simple' ? 'web_app' : 'api_service',
        name: `${templateConfig?.name.toLowerCase().replace(/\s+/g, '-')}-${Date.now()}`,
        environment: 'dev',
        region: 'us-east-1',
        config: {
          template: templateId,
          auto_generated: true
        },
        tags: {
          CreatedBy: 'Template Gallery',
          Template: templateId
        }
      });

      console.log('Deployment request created:', response);
      
      if (response.status === 'pending_approval') {
        alert(`✅ Deployment request submitted!\nRequest ID: ${response.job_id}\n\n⏳ Your request is now pending admin approval.\nPlease check with an administrator to approve your deployment.`);
      } else {
        alert(`✅ Deployment request submitted!\nJob ID: ${response.job_id}\nStatus: ${response.status}`);
      }
      
    } catch (error) {
      console.error('Deployment failed:', error);
      alert(`❌ Deployment failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    } finally {
      setDeployingTemplate(null);
    }
  };

  return (
    <section className="space-y-4" aria-labelledby="template-gallery-heading">
      <div className="flex items-center justify-between">
        <h2 id="template-gallery-heading" className="text-2xl font-bold">Template Gallery</h2>
        <Button variant="outline" className="gap-2">
          <Plus className="h-4 w-4" />
          Custom Template
        </Button>
      </div>
      
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {templates.map((template) => (
          <Card 
            key={template.id} 
            className="hover:shadow-md transition-shadow cursor-pointer focus-within:ring-2 focus-within:ring-ring"
          >
            <CardHeader>
              <div className="flex items-center gap-3">
                <div className="p-2 bg-primary/10 rounded-lg text-primary" aria-hidden="true">
                  {template.icon}
                </div>
                <div>
                  <CardTitle className="text-lg">{template.name}</CardTitle>
                  <p className="text-sm text-muted-foreground">{template.cost}</p>
                </div>
              </div>
            </CardHeader>
            <CardContent className="space-y-4">
              <p className="text-sm">{template.description}</p>
              
              <div className="space-y-2">
                <p className="text-xs font-medium text-muted-foreground">FEATURES</p>
                <div className="flex flex-wrap gap-1">
                  {template.features.map((feature) => (
                    <Badge key={feature} variant="secondary" className="text-xs">
                      {feature}
                    </Badge>
                  ))}
                </div>
              </div>
              
              <div className="space-y-2">
                <p className="text-xs font-medium text-muted-foreground">RUNTIME</p>
                <p className="text-xs">{template.runtime}</p>
              </div>
              
              <div className="flex gap-2 pt-2">
                <Button 
                  className="flex-1" 
                  size="sm" 
                  aria-label={`Deploy ${template.name}`}
                  onClick={() => handleDeploy(template.id)}
                  disabled={deployingTemplate === template.id}
                >
                  {deployingTemplate === template.id ? (
                    <>
                      <RefreshCw className="h-3 w-3 mr-1 animate-spin" />
                      Deploying...
                    </>
                  ) : (
                    'Deploy'
                  )}
                </Button>
                <Button variant="outline" size="sm" aria-label={`Preview ${template.name}`}>
                  Preview
                </Button>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </section>
  );
};

/**
 * Service Manager Component
 */
const ServiceManager: React.FC = () => {
  const { requests, currentUser } = useAppStore();
  const userServices = requests.filter(req => req.requester === currentUser);

  const StatusIcon: React.FC<{ status: string }> = ({ status }) => {
    switch (status.toLowerCase()) {
      case 'completed':
        return <CheckCircle className="h-4 w-4 text-green-600" aria-label="Completed" />;
      case 'failed':
        return <XCircle className="h-4 w-4 text-red-600" aria-label="Failed" />;
      case 'running':
      case 'processing':
        return <Activity className="h-4 w-4 text-blue-600" aria-label="Running" />;
      default:
        return <Clock className="h-4 w-4 text-yellow-600" aria-label="Pending" />;
    }
  };

  const getStatusVariant = (status: string): 'default' | 'secondary' | 'destructive' | 'outline' => {
    switch (status.toLowerCase()) {
      case 'completed': return 'default';
      case 'failed': return 'destructive';
      case 'running':
      case 'processing': return 'secondary';
      default: return 'outline';
    }
  };

  return (
    <section className="space-y-4" aria-labelledby="service-manager-heading">
      <div className="flex items-center justify-between">
        <h2 id="service-manager-heading" className="text-2xl font-bold">Service Manager</h2>
        <Button className="gap-2">
          <Plus className="h-4 w-4" />
          New Service
        </Button>
      </div>
      
      <Card>
        <CardContent className="p-0">
          <div className="border-b p-4">
            <h3 className="font-medium">Active Services</h3>
          </div>
          {userServices.length === 0 ? (
            <div className="text-center py-12 text-muted-foreground">
              <Server className="mx-auto h-12 w-12 mb-4" aria-hidden="true" />
              <h3 className="text-lg font-medium mb-2">No services deployed</h3>
              <p className="mb-4">Deploy your first service to get started</p>
              <Button>Browse Templates</Button>
            </div>
          ) : (
            <div className="divide-y" role="list">
              {userServices.map((service) => (
                <div key={service.id} className="p-4 flex items-center justify-between" role="listitem">
                  <div className="flex items-center gap-4">
                    <StatusIcon status={service.status} />
                    <div>
                      <h4 className="font-medium">{service.id}</h4>
                      <p className="text-sm text-muted-foreground">
                        {service.resource_type} • {new Date(service.created_at).toLocaleDateString()}
                      </p>
                    </div>
                  </div>
                  <div className="flex items-center gap-2">
                    <Badge variant={getStatusVariant(service.status)}>
                      {service.status}
                    </Badge>
                    <Button variant="ghost" size="sm" aria-label="View service details">
                      <Eye className="h-4 w-4" />
                    </Button>
                    <Button variant="ghost" size="sm" aria-label="Service settings">
                      <Settings className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
    </section>
  );
};

/**
 * API Documentation component
 */
const ApiDocumentation: React.FC = () => (
  <Card>
    <CardHeader>
      <CardTitle>FastAPI Documentation</CardTitle>
      <CardDescription>Interactive API documentation and testing</CardDescription>
    </CardHeader>
    <CardContent>
      <div className="space-y-4">
        <div className="grid gap-4 md:grid-cols-2">
          <Button asChild className="h-24 flex-col">
            <a 
              href="http://localhost:8000/docs" 
              target="_blank" 
              rel="noopener noreferrer"
              aria-label="Open Swagger UI documentation in new tab"
            >
              <Code className="h-6 w-6 mb-2" />
              <span>Interactive Docs</span>
              <span className="text-xs opacity-75">Swagger UI</span>
            </a>
          </Button>
          <Button asChild variant="outline" className="h-24 flex-col">
            <a 
              href="http://localhost:8000/redoc" 
              target="_blank" 
              rel="noopener noreferrer"
              aria-label="Open ReDoc documentation in new tab"
            >
              <Settings className="h-6 w-6 mb-2" />
              <span>ReDoc</span>
              <span className="text-xs opacity-75">Alternative docs</span>
            </a>
          </Button>
        </div>
        
        <div className="border rounded-lg p-4 bg-muted/50">
          <h4 className="font-medium mb-2">Available Endpoints</h4>
          <div className="space-y-2 text-sm" role="list">
            <div className="flex justify-between" role="listitem">
              <code className="text-green-600">POST /api/v1/create-infra</code>
              <span className="text-muted-foreground">Deploy infrastructure</span>
            </div>
            <div className="flex justify-between" role="listitem">
              <code className="text-red-600">POST /api/v1/destroy-infra</code>
              <span className="text-muted-foreground">Destroy resources</span>
            </div>
            <div className="flex justify-between" role="listitem">
              <code className="text-blue-600">GET /api/v1/jobs</code>
              <span className="text-muted-foreground">List all jobs</span>
            </div>
            <div className="flex justify-between" role="listitem">
              <code className="text-blue-600">GET /api/v1/job-status/{'{job_id}'}</code>
              <span className="text-muted-foreground">Get job status</span>
            </div>
          </div>
        </div>
      </div>
    </CardContent>
  </Card>
);

/**
 * Main Developer Dashboard Component
 * 
 * Enterprise-grade dashboard with comprehensive functionality:
 * - Template deployment and management
 * - Real-time service monitoring
 * - Integrated API documentation
 * - Performance metrics and logging
 * - Accessibility and TypeScript compliance
 */
export function DeveloperDashboard(): JSX.Element {
  const { 
    currentUser, 
    jobs, 
    requests, 
    loading, 
    error, 
    fetchJobs, 
    fetchRequests,
    connectWebSocket,
    disconnectWebSocket 
  } = useAppStore();

  const [activeTab, setActiveTab] = useState<string>('overview');
  const [refreshing, setRefreshing] = useState<boolean>(false);

  // Memoized metrics calculations for performance
  const metrics: DashboardMetrics = useMemo(() => {
    const userJobs = jobs.filter(job => job.job_id.includes(currentUser || 'user'));
    const userRequests = requests.filter(req => req.requester === currentUser);

    const calculateHealthScore = (requests: any[]): number => {
      if (requests.length === 0) return 100;
      const successful = requests.filter(req => req.status === 'COMPLETED').length;
      const failed = requests.filter(req => req.status === 'FAILED').length;
      const total = successful + failed;
      return total === 0 ? 100 : Math.round((successful / total) * 100);
    };

    return {
      totalServices: userRequests.filter(req => req.status === 'COMPLETED').length,
      runningServices: userRequests.filter(req => req.status === 'PROCESSING').length,
      pendingDeployments: userRequests.filter(req => req.status === 'PENDING').length,
      failedServices: userRequests.filter(req => req.status === 'FAILED').length,
      totalRequests: userRequests.length,
      recentJobs: userJobs.slice(0, 5),
      healthScore: calculateHealthScore(userRequests)
    };
  }, [jobs, requests, currentUser]);

  // Optimized refresh handler
  const handleRefresh = useCallback(async (): Promise<void> => {
    setRefreshing(true);
    try {
      await Promise.all([fetchJobs(), fetchRequests()]);
    } catch (error) {
      console.error('Failed to refresh dashboard data:', error);
    } finally {
      setRefreshing(false);
    }
  }, [fetchJobs, fetchRequests]);

  // Initialize dashboard with cleanup
  useEffect(() => {
    const initializeDashboard = async (): Promise<void> => {
      await handleRefresh();
      connectWebSocket();
    };

    initializeDashboard();

    return () => {
      disconnectWebSocket();
    };
  }, [handleRefresh, connectWebSocket, disconnectWebSocket]);

  if (loading && !refreshing) {
    return <LoadingSpinner />;
  }

  return (
    <main className="space-y-6 p-6" role="main" aria-labelledby="dashboard-heading">
      {/* Header Section */}
      <header className="flex items-center justify-between">
        <div>
          <h1 id="dashboard-heading" className="text-3xl font-bold tracking-tight">
            Developer Dashboard
          </h1>
          <p className="text-muted-foreground">
            Welcome back, {currentUser}! Manage your infrastructure and services.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={handleRefresh}
            disabled={refreshing}
            className="gap-2"
            aria-label="Refresh dashboard data"
          >
            <RefreshCw className={`h-4 w-4 ${refreshing ? 'animate-spin' : ''}`} />
            Refresh
          </Button>
        </div>
      </header>

      {/* Metrics Overview */}
      <section aria-labelledby="metrics-heading">
        <h2 id="metrics-heading" className="sr-only">Dashboard Metrics</h2>
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          <MetricCard
            title="Active Services"
            value={metrics.totalServices}
            description="Running successfully"
            icon={<Server className="h-4 w-4" />}
            variant="success"
          />
          <MetricCard
            title="Deploying"
            value={metrics.runningServices}
            description="In progress"
            icon={<Activity className="h-4 w-4" />}
            variant="warning"
          />
          <MetricCard
            title="Pending"
            value={metrics.pendingDeployments}
            description="Awaiting approval"
            icon={<Clock className="h-4 w-4" />}
            variant="info"
          />
          <MetricCard
            title="Health Score"
            value={`${metrics.healthScore}%`}
            description="Service reliability"
            icon={<TrendingUp className="h-4 w-4" />}
            variant={metrics.healthScore > 90 ? 'success' : metrics.healthScore > 70 ? 'warning' : 'error'}
          />
        </div>
      </section>

      {/* Main Content Tabs */}
      <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-4">
        <TabsList className="grid w-full grid-cols-4" role="tablist">
          <TabsTrigger value="overview" role="tab">Overview</TabsTrigger>
          <TabsTrigger value="templates" role="tab">Templates</TabsTrigger>
          <TabsTrigger value="services" role="tab">Services</TabsTrigger>
          <TabsTrigger value="docs" role="tab">API Docs</TabsTrigger>
        </TabsList>

        <TabsContent value="overview" className="space-y-4" role="tabpanel">
          <Suspense fallback={<LoadingSpinner />}>
            <div className="grid gap-4 md:grid-cols-2">
              <Card>
                <CardHeader>
                  <CardTitle>Quick Deploy</CardTitle>
                  <CardDescription>Deploy from popular templates</CardDescription>
                </CardHeader>
                <CardContent className="space-y-3">
                  <Link to="/deploy" className="block">
                    <Button className="w-full justify-start" variant="outline">
                      <Globe className="mr-2 h-4 w-4" />
                      Web Application
                    </Button>
                  </Link>
                  <Link to="/deploy" className="block">
                    <Button className="w-full justify-start" variant="outline">
                      <Server className="mr-2 h-4 w-4" />
                      API Service
                    </Button>
                  </Link>
                  <Link to="/sirwan-test-s3" className="block">
                    <Button className="w-full justify-start" variant="outline">
                      <Database className="mr-2 h-4 w-4" />
                      Sirwan Test
                    </Button>
                  </Link>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>Recent Activity</CardTitle>
                  <CardDescription>Your latest deployments</CardDescription>
                </CardHeader>
                <CardContent>
                  {metrics.recentJobs.length === 0 ? (
                    <div className="text-center py-8 text-muted-foreground">
                      <Activity className="mx-auto h-8 w-8 mb-2" />
                      <p>No recent activity</p>
                    </div>
                  ) : (
                    <div className="space-y-3">
                      {metrics.recentJobs.map((job) => (
                        <div key={job.job_id} className="flex items-center justify-between">
                          <div className="flex items-center gap-3">
                            <div>
                              <p className="text-sm font-medium">{job.job_id}</p>
                              <p className="text-xs text-muted-foreground">
                                {job.created_at && new Date(job.created_at).toLocaleString()}
                              </p>
                            </div>
                          </div>
                          <Badge variant="secondary">{job.status}</Badge>
                        </div>
                      ))}
                    </div>
                  )}
                </CardContent>
              </Card>
            </div>
          </Suspense>
        </TabsContent>

        <TabsContent value="templates" className="space-y-4" role="tabpanel">
          <Suspense fallback={<LoadingSpinner />}>
            <TemplateGallery />
          </Suspense>
        </TabsContent>

        <TabsContent value="services" className="space-y-4" role="tabpanel">
          <Suspense fallback={<LoadingSpinner />}>
            <ServiceManager />
          </Suspense>
        </TabsContent>

        <TabsContent value="docs" className="space-y-4" role="tabpanel">
          <Suspense fallback={<LoadingSpinner />}>
            <ApiDocumentation />
          </Suspense>
        </TabsContent>
      </Tabs>

      {/* Error Display */}
      {error && <ErrorDisplay error={error} />}
    </main>
  );
}
