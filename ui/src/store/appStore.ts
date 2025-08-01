import { create } from 'zustand';
import { StateCreator } from 'zustand';
import { apiClient, JobStatus, JobLog, CreateInfraRequest } from '../services/apiClient';

// Updated interfaces for Redis Queue backend
export interface Job {
  job_id: string;
  status: 'queued' | 'running' | 'completed' | 'failed' | 'cancelled';
  created_at?: string;
  completed_at?: string;
  error_message?: string;
  terraform_output?: Record<string, any>;
  logs?: JobLog[];
}

// Request interface for compatibility with components
interface Request {
  id: string;
  requester: string;
  status: string;
  created_at: string;
  updated_at?: string; // Add missing property
  resource_type: string;
  resource_config: Record<string, any>;
}

interface AppState {
  // Authentication state
  isAuthenticated: boolean;
  currentUser: string | null;
  userRole: 'developer' | 'admin';
  
  // Auth actions
  login: (username: string, role: 'developer' | 'admin') => void;
  logout: () => void;
  setUserRole: (role: 'developer' | 'admin') => void;
  
  // Job Management (with backward compatibility)
  jobs: Job[];
  requests: Request[]; // For component compatibility
  currentJob: Job | null;
  isLoading: boolean;
  loading: boolean; // For component compatibility
  error: string | null;
  
  // WebSocket Connection
  wsConnection: WebSocket | null;
  isConnected: boolean;
  
  // Actions
  createInfrastructure: (request: CreateInfraRequest) => Promise<string>; // Returns job ID
  destroyInfrastructure: (request: CreateInfraRequest) => Promise<string>; // Returns job ID
  fetchJobStatus: (jobId: string) => Promise<void>;
  fetchJobLogs: (jobId: string) => Promise<void>;
  fetchJobs: () => Promise<void>;
  fetchRequests: () => Promise<void>; // For component compatibility
  approveRequest: (requestId: string) => Promise<void>; // For admin dashboard
  rejectRequest: (requestId: string, reason: string) => Promise<void>; // For admin dashboard
  connectWebSocket: (jobId?: string) => void;
  disconnectWebSocket: () => void;
  setCurrentJob: (job: Job | null) => void;
  clearError: () => void;
}

const createAppStore: StateCreator<AppState> = (set, get) => ({
  // Initial state
  isAuthenticated: false,
  currentUser: null,
  userRole: 'developer',
  jobs: [],
  requests: [], // For component compatibility
  currentJob: null,
  isLoading: false,
  loading: false, // For component compatibility
  error: null,
  wsConnection: null,
  isConnected: false,
  
  // Authentication actions
  login: (username: string, role: 'developer' | 'admin') => {
    set({ 
      isAuthenticated: true, 
      currentUser: username, 
      userRole: role 
    });
  },
  
  logout: () => {
    const { disconnectWebSocket } = get();
    disconnectWebSocket(); // Clean up WebSocket on logout
    set({ 
      isAuthenticated: false, 
      currentUser: null, 
      userRole: 'developer',
      jobs: [],
      requests: [],
      currentJob: null 
    });
  },
  
  // User actions
  setUserRole: (role: 'developer' | 'admin') => set({ userRole: role }),

  // Infrastructure actions
  createInfrastructure: async (request: CreateInfraRequest): Promise<string> => {
    set({ isLoading: true, error: null });
    
    try {
      const response = await apiClient.createInfrastructure(request);
      
      // Add job to list with initial status
      const newJob: Job = {
        job_id: response.job_id,
        status: 'queued',
        created_at: new Date().toISOString(),
      };
      
      set((state: AppState) => ({
        jobs: [newJob, ...state.jobs],
        currentJob: newJob,
        isLoading: false
      }));
      
      return response.job_id;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Failed to create infrastructure';
      set({ error: errorMessage, isLoading: false });
      throw error;
    }
  },

  destroyInfrastructure: async (request: CreateInfraRequest): Promise<string> => {
    set({ isLoading: true, error: null });
    
    try {
      const response = await apiClient.destroyInfrastructure(request);
      
      // Add job to list with initial status
      const newJob: Job = {
        job_id: response.job_id,
        status: 'queued',
        created_at: new Date().toISOString(),
      };
      
      set((state: AppState) => ({
        jobs: [newJob, ...state.jobs],
        currentJob: newJob,
        isLoading: false
      }));
      
      return response.job_id;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Failed to destroy infrastructure';
      set({ error: errorMessage, isLoading: false });
      throw error;
    }
  },

  fetchJobStatus: async (jobId: string): Promise<void> => {
    try {
      const jobStatus = await apiClient.getJobStatus(jobId);
      
      set((state: AppState) => {
        const updatedJobs = state.jobs.map((job: Job) => 
          job.job_id === jobId 
            ? { ...job, ...jobStatus }
            : job
        );
        
        // If this job wasn't in the list, add it
        if (!state.jobs.find((job: Job) => job.job_id === jobId)) {
          updatedJobs.unshift({ ...jobStatus });
        }
        
        return {
          jobs: updatedJobs,
          currentJob: state.currentJob?.job_id === jobId 
            ? { ...state.currentJob, ...jobStatus }
            : state.currentJob
        };
      });
    } catch (error) {
      console.error('Failed to fetch job status:', error);
      set({ error: error instanceof Error ? error.message : 'Failed to fetch job status' });
    }
  },

  fetchJobLogs: async (jobId: string): Promise<void> => {
    try {
      const response = await apiClient.getJobLogs(jobId);
      
      set((state: AppState) => {
        const updatedJobs = state.jobs.map((job: Job) => 
          job.job_id === jobId 
            ? { ...job, logs: response.logs }
            : job
        );
        
        return {
          jobs: updatedJobs,
          currentJob: state.currentJob?.job_id === jobId 
            ? { ...state.currentJob, logs: response.logs }
            : state.currentJob
        };
      });
    } catch (error) {
      console.error('Failed to fetch job logs:', error);
    }
  },

  fetchJobs: async (): Promise<void> => {
    set({ isLoading: true, error: null });
    
    try {
      const response = await apiClient.listJobs();
      const jobs: Job[] = response.jobs.map(job => ({ ...job }));
      
      set({ jobs, isLoading: false });
    } catch (error) {
      console.error('Failed to fetch jobs:', error);
      set({ 
        error: error instanceof Error ? error.message : 'Failed to fetch jobs',
        isLoading: false 
      });
    }
  },

  connectWebSocket: (jobId?: string): void => {
    const { wsConnection, disconnectWebSocket } = get();
    
    // Close existing connection
    if (wsConnection) {
      disconnectWebSocket();
    }
    
    try {
      const ws = apiClient.createWebSocket(jobId);
      
      ws.onopen = () => {
        console.log('WebSocket connected');
        set({ wsConnection: ws, isConnected: true });
      };
      
      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          
          if (data.type === 'job_status' && data.job_id) {
            // Update job status from WebSocket
            set((state: AppState) => ({
              jobs: state.jobs.map((job: Job) => 
                job.job_id === data.job_id 
                  ? { ...job, ...data }
                  : job
              ),
              currentJob: state.currentJob?.job_id === data.job_id 
                ? { ...state.currentJob, ...data }
                : state.currentJob
            }));
          }
          
          if (data.type === 'job_log' && data.job_id) {
            // Add new log entry
            set((state: AppState) => ({
              jobs: state.jobs.map((job: Job) => 
                job.job_id === data.job_id 
                  ? { ...job, logs: [...(job.logs || []), data.log] }
                  : job
              ),
              currentJob: state.currentJob?.job_id === data.job_id && state.currentJob
                ? { ...state.currentJob, logs: [...(state.currentJob.logs || []), data.log] }
                : state.currentJob
            }));
          }
        } catch (error) {
          console.error('Failed to parse WebSocket message:', error);
        }
      };
      
      ws.onclose = () => {
        console.log('WebSocket disconnected');
        set({ wsConnection: null, isConnected: false });
      };
      
      ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        set({ wsConnection: null, isConnected: false });
      };
      
    } catch (error) {
      console.error('Failed to create WebSocket connection:', error);
      set({ error: 'Failed to establish real-time connection' });
    }
  },

  disconnectWebSocket: (): void => {
    const { wsConnection } = get();
    if (wsConnection) {
      wsConnection.close();
      set({ wsConnection: null, isConnected: false });
    }
  },

  setCurrentJob: (job: Job | null) => set({ currentJob: job }),
  
  clearError: () => set({ error: null }),

  // Component compatibility methods
  fetchRequests: async (): Promise<void> => {
    set({ loading: true, error: null });
    
    try {
      // Read requests from localStorage instead of backend API
      const pendingRequests = JSON.parse(localStorage.getItem('pending-requests') || '[]');
      
      // Convert to the format expected by admin dashboard
      const requests: Request[] = pendingRequests.map((req: any) => ({
        id: req.id,
        requester: req.requested_by,
        status: req.status.toUpperCase(),
        created_at: req.created_at,
        updated_at: req.updated_at,
        resource_type: req.request_type.toUpperCase(),
        resource_config: req.configuration
      }));
      
      set({ 
        requests, 
        loading: false 
      });
      
    } catch (error) {
      console.error('Failed to fetch requests from localStorage:', error);
      set({ 
        error: 'Failed to fetch deployment requests', 
        loading: false 
      });
    }
  },

  approveRequest: async (requestId: string): Promise<void> => {
    try {
      // Update localStorage
      const storedRequests = localStorage.getItem('pending-requests');
      if (storedRequests) {
        const requests = JSON.parse(storedRequests);
        const updatedRequests = requests.map((req: any) =>
          req.id === requestId ? { ...req, status: 'APPROVED' } : req
        );
        localStorage.setItem('pending-requests', JSON.stringify(updatedRequests));
      }
      
      // Update local state
      set((state: AppState) => ({
        requests: state.requests.map(req => 
          req.id === requestId 
            ? { ...req, status: 'APPROVED' }
            : req
        )
      }));
      
      console.log(`Request ${requestId} approved successfully`);
    } catch (error) {
      console.error('Failed to approve request:', error);
      set({ error: 'Failed to approve request' });
    }
  },

  rejectRequest: async (requestId: string, reason: string): Promise<void> => {
    try {
      // Update localStorage
      const storedRequests = localStorage.getItem('pending-requests');
      if (storedRequests) {
        const requests = JSON.parse(storedRequests);
        const updatedRequests = requests.map((req: any) =>
          req.id === requestId ? { ...req, status: 'REJECTED', rejectionReason: reason } : req
        );
        localStorage.setItem('pending-requests', JSON.stringify(updatedRequests));
      }
      
      // Update local state
      set((state: AppState) => ({
        requests: state.requests.map(req => 
          req.id === requestId 
            ? { ...req, status: 'REJECTED' }
            : req
        )
      }));
      
      console.log(`Request ${requestId} rejected: ${reason}`);
    } catch (error) {
      console.error('Failed to reject request:', error);
      set({ error: 'Failed to reject request' });
    }
  },
});

export const useAppStore = create<AppState>(createAppStore);
