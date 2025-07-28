import { create } from 'zustand';

interface ProvisioningRequest {
  id: string;
  requester: string;
  resource_type: 'WEB_APP' | 'API_SERVICE' | 'DATA_PIPELINE';
  resource_config: {
    serviceName?: string;
    service_name?: string;
    environment?: string;
    instanceType?: string;
    region?: string;
    [key: string]: any;
  };
  status: 'PENDING' | 'APPROVED' | 'REJECTED' | 'PROCESSING' | 'COMPLETED' | 'FAILED';
  created_at: string;
  updated_at?: string;
  approval_notes?: string;
}

interface AppState {
  // User state
  userRole: 'developer' | 'admin';
  setUserRole: (role: 'developer' | 'admin') => void;
  
  // Request state
  requests: ProvisioningRequest[];
  loading: boolean;
  error: string | null;
  
  // Actions
  fetchRequests: () => Promise<void>;
  submitRequest: (requestData: Omit<ProvisioningRequest, 'id' | 'created_at' | 'updated_at'>) => Promise<void>;
  approveRequest: (requestId: string) => Promise<void>;
  rejectRequest: (requestId: string, reason: string) => Promise<void>;
}

export const useAppStore = create<AppState>((set, get) => ({
  // Initial state
  userRole: 'developer',
  requests: [],
  loading: false,
  error: null,
  
  // User actions
  setUserRole: (role: 'developer' | 'admin') => set({ userRole: role }),

  // API actions
  fetchRequests: async () => {
    set({ loading: true, error: null });
    
    try {
      const response = await fetch('http://localhost:8000/api/requests');
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      const requests = await response.json();
      set({ requests, loading: false });
    } catch (error) {
      console.error('Error fetching requests:', error);
      // Mock data for demo
      const mockRequests: ProvisioningRequest[] = [
        {
          id: '1',
          requester: 'developer1',
          resource_type: 'WEB_APP',
          resource_config: {
            serviceName: 'my-web-app',
            environment: 'production',
            region: 'us-east-1'
          },
          status: 'PENDING',
          created_at: new Date().toISOString()
        },
        {
          id: '2',
          requester: 'developer2',
          resource_type: 'API_SERVICE',
          resource_config: {
            serviceName: 'user-api',
            environment: 'staging',
            region: 'us-west-2'
          },
          status: 'COMPLETED',
          created_at: new Date(Date.now() - 86400000).toISOString(),
          updated_at: new Date().toISOString()
        },
        {
          id: '3',
          requester: 'developer1',
          resource_type: 'DATA_PIPELINE',
          resource_config: {
            serviceName: 'analytics-pipeline',
            environment: 'production',
            region: 'eu-west-1'
          },
          status: 'PROCESSING',
          created_at: new Date(Date.now() - 3600000).toISOString()
        }
      ];
      set({ requests: mockRequests, loading: false, error: 'Using mock data - backend not available' });
    }
  },

  submitRequest: async (requestData) => {
    set({ loading: true, error: null });
    
    try {
      const response = await fetch('http://localhost:8000/api/requests', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestData),
      });
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const newRequest = await response.json();
      set((state) => ({
        requests: [newRequest, ...state.requests],
        loading: false
      }));
    } catch (error) {
      console.error('Error submitting request:', error);
      // Mock submission for demo
      const mockRequest: ProvisioningRequest = {
        id: Date.now().toString(),
        ...requestData,
        created_at: new Date().toISOString()
      };
      set((state) => ({
        requests: [mockRequest, ...state.requests],
        loading: false,
        error: 'Request submitted with mock data - backend not available'
      }));
    }
  },

  approveRequest: async (requestId: string) => {
    set({ loading: true, error: null });
    
    try {
      const response = await fetch(`http://localhost:8000/api/requests/${requestId}/approve`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      });
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const updatedRequest = await response.json();
      set((state) => ({
        requests: state.requests.map(req => 
          req.id === requestId ? updatedRequest : req
        ),
        loading: false
      }));
    } catch (error) {
      console.error('Error approving request:', error);
      // Mock approval for demo
      set((state) => ({
        requests: state.requests.map(req => 
          req.id === requestId 
            ? { ...req, status: 'APPROVED' as const, updated_at: new Date().toISOString() }
            : req
        ),
        loading: false,
        error: 'Request approved with mock data - backend not available'
      }));
    }
  },

  rejectRequest: async (requestId: string, reason: string) => {
    set({ loading: true, error: null });
    
    try {
      const response = await fetch(`http://localhost:8000/api/requests/${requestId}/reject`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ reason }),
      });
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const updatedRequest = await response.json();
      set((state) => ({
        requests: state.requests.map(req => 
          req.id === requestId ? updatedRequest : req
        ),
        loading: false
      }));
    } catch (error) {
      console.error('Error rejecting request:', error);
      // Mock rejection for demo
      set((state) => ({
        requests: state.requests.map(req => 
          req.id === requestId 
            ? { 
                ...req, 
                status: 'REJECTED' as const, 
                updated_at: new Date().toISOString(),
                approval_notes: reason
              }
            : req
        ),
        loading: false,
        error: 'Request rejected with mock data - backend not available'
      }));
    }
  },
}));
