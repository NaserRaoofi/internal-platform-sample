/**
 * API Service - New Redis Queue Backend Integration
 * ==============================================
 * 
 * Updated to work with FastAPI + Redis Queue architecture
 */

// API Configuration
declare const process: {
  env: {
    REACT_APP_API_URL?: string;
    REACT_APP_WS_URL?: string;
  };
};

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000';
const WS_BASE_URL = process.env.REACT_APP_WS_URL || 'ws://localhost:8000';

// API Types
export interface CreateInfraRequest {
  resource_type: 'ec2' | 's3' | 'web_app' | 'api_service' | 'vpc' | 'rds';
  name: string;
  environment: 'dev' | 'staging' | 'prod';
  region: string;
  config: Record<string, any>;
  tags: Record<string, string>;
}

export interface JobResponse {
  job_id: string;
  status: string;
  message: string;
}

export interface JobStatus {
  job_id: string;
  status: 'queued' | 'running' | 'completed' | 'failed' | 'cancelled';
  created_at?: string;
  completed_at?: string;
  error_message?: string;
  terraform_output?: Record<string, any>;
}

export interface JobLog {
  timestamp: string;
  level: string;
  message: string;
  step?: string;
}

export interface JobLogsResponse {
  job_id: string;
  logs: JobLog[];
}

export interface JobListResponse {
  jobs: JobStatus[];
  total: number;
  limit: number;
  offset: number;
}

// API Client Class
class ApiClient {
  private baseUrl: string;

  constructor(baseUrl: string = API_BASE_URL) {
    this.baseUrl = baseUrl;
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`;
    
    const response = await fetch(url, {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
      ...options,
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.detail || `HTTP ${response.status}: ${response.statusText}`);
    }

    return response.json();
  }

  // Infrastructure Operations
  async createInfrastructure(request: CreateInfraRequest): Promise<JobResponse> {
    return this.request<JobResponse>('/api/v1/create-infra', {
      method: 'POST',
      body: JSON.stringify(request),
    });
  }

  async destroyInfrastructure(request: CreateInfraRequest): Promise<JobResponse> {
    return this.request<JobResponse>('/destroy-infra', {
      method: 'POST',
      body: JSON.stringify(request),
    });
  }

  // Job Management
  async getJobStatus(jobId: string): Promise<JobStatus> {
    return this.request<JobStatus>(`/job-status/${jobId}`);
  }

  async getJobLogs(jobId: string, limit: number = 100): Promise<JobLogsResponse> {
    return this.request<JobLogsResponse>(`/job-logs/${jobId}?limit=${limit}`);
  }

  async listJobs(
    status?: string,
    limit: number = 50,
    offset: number = 0
  ): Promise<JobListResponse> {
    const params = new URLSearchParams();
    if (status) params.append('status', status);
    params.append('limit', limit.toString());
    params.append('offset', offset.toString());

    return this.request<JobListResponse>(`/jobs?${params.toString()}`);
  }

  // Health Check
  async healthCheck(): Promise<{ status: string; timestamp: string }> {
    return this.request<{ status: string; timestamp: string }>('/health');
  }

  // WebSocket Connection
  createWebSocket(jobId?: string): WebSocket {
    const wsUrl = jobId 
      ? `${WS_BASE_URL}/ws/${jobId}`
      : `${WS_BASE_URL}/ws`;
    
    return new WebSocket(wsUrl);
  }
}

// Export singleton instance
export const apiClient = new ApiClient();

// Helper functions for common operations
export const createWebAppService = async (data: {
  serviceName: string;
  repoUrl: string;
  environment: 'dev' | 'staging' | 'prod';
  language: string;
  enableDatabase: boolean;
  enableMonitoring: boolean;
}): Promise<JobResponse> => {
  return apiClient.createInfrastructure({
    resource_type: 'web_app',
    name: data.serviceName,
    environment: data.environment,
    region: 'us-east-1',
    config: {
      repo_url: data.repoUrl,
      language: data.language,
      enable_database: data.enableDatabase,
      enable_monitoring: data.enableMonitoring,
    },
    tags: {
      CreatedBy: 'UI',
      ServiceType: 'web_app',
      Repository: data.repoUrl,
    },
  });
};

export const createEC2Instance = async (data: {
  name: string;
  environment: 'dev' | 'staging' | 'prod';
  instanceType: string;
  keyPairName?: string;
}): Promise<JobResponse> => {
  return apiClient.createInfrastructure({
    resource_type: 'ec2',
    name: data.name,
    environment: data.environment,
    region: 'us-east-1',
    config: {
      instance_type: data.instanceType,
      key_pair_name: data.keyPairName,
    },
    tags: {
      CreatedBy: 'UI',
      ResourceType: 'ec2',
    },
  });
};

export const createS3Bucket = async (data: {
  name: string;
  environment: 'dev' | 'staging' | 'prod';
  versioningEnabled: boolean;
  encryptionEnabled: boolean;
}): Promise<JobResponse> => {
  return apiClient.createInfrastructure({
    resource_type: 's3',
    name: data.name,
    environment: data.environment,
    region: 'us-east-1',
    config: {
      versioning_enabled: data.versioningEnabled,
      encryption_enabled: data.encryptionEnabled,
    },
    tags: {
      CreatedBy: 'UI',
      ResourceType: 's3',
    },
  });
};

export const createSirwanTestS3 = async (data: {
  bucketName: string;
  environment: 'dev' | 'staging' | 'prod';
  bucketPurpose: string;
  versioningEnabled: boolean;
  encryptionEnabled: boolean;
  publicReadAccess: boolean;
  websiteEnabled: boolean;
  corsEnabled: boolean;
  lifecycleEnabled: boolean;
  backupEnabled: boolean;
  accessLoggingEnabled: boolean;
  forceDestroy: boolean;
  // EC2 Configuration
  ec2Enabled: boolean;
  ec2InstanceType: string;
  ec2Purpose: string;
  ec2KeyName: string;
  ec2EnableS3Integration: boolean;
  ec2RootVolumeSize: number;
  ec2MonitoringEnabled: boolean;
  ec2CloudwatchLogsEnabled: boolean;
  ec2EnableElasticIp: boolean;
}): Promise<JobResponse> => {
  return apiClient.createInfrastructure({
    resource_type: 's3',
    name: data.bucketName,
    environment: data.environment,
    region: 'us-east-1',
    config: {
      template: 'sirwan-test',  // ✅ Specify which template to use
      bucket_name: data.bucketName,
      bucket_purpose: data.bucketPurpose,
      versioning_enabled: data.versioningEnabled,
      encryption_enabled: data.encryptionEnabled,
      public_read_access: data.publicReadAccess,
      website_enabled: data.websiteEnabled,
      cors_enabled: data.corsEnabled,
      lifecycle_enabled: data.lifecycleEnabled,
      backup_enabled: data.backupEnabled,
      access_logging_enabled: data.accessLoggingEnabled,
      force_destroy: data.forceDestroy,
      // EC2 Configuration
      ec2_enabled: data.ec2Enabled,
      ec2_instance_type: data.ec2InstanceType,
      ec2_purpose: data.ec2Purpose,
      ec2_key_name: data.ec2KeyName,
      ec2_enable_s3_integration: data.ec2EnableS3Integration,
      ec2_root_volume_size: data.ec2RootVolumeSize,
      ec2_monitoring_enabled: data.ec2MonitoringEnabled,
      ec2_cloudwatch_logs_enabled: data.ec2CloudwatchLogsEnabled,
      ec2_enable_elastic_ip: data.ec2EnableElasticIp,
    },
    tags: {
      CreatedBy: 'UI',
      ResourceType: 'sirwan-test-s3-ec2',
      Template: 'sirwan-test',  // ✅ Also in tags for clarity
      Owner: 'sirwan',
      HasEC2: data.ec2Enabled ? 'true' : 'false',
    },
  });
};
