import React, { useEffect } from 'react';

interface JobStatusProps {
  jobId: string;
  onClose?: () => void;
}

export const JobStatus = ({ jobId, onClose }: JobStatusProps) => {
  const [job, setJob] = React.useState<any>(null);
  const [loading, setLoading] = React.useState(true);

  useEffect(() => {
    const fetchJobStatus = async () => {
      try {
        const response = await fetch(`/job-status/${jobId}`);
        if (response.ok) {
          const data = await response.json();
          setJob(data);
        }
      } catch (error) {
        console.error('Failed to fetch job status:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchJobStatus();
    const interval = setInterval(fetchJobStatus, 5000);
    return () => clearInterval(interval);
  }, [jobId]);

  if (loading) {
    return (
      <div className="max-w-2xl mx-auto bg-white p-6 rounded-lg shadow">
        <div className="text-center">Loading job status...</div>
      </div>
    );
  }

  if (!job) {
    return (
      <div className="max-w-2xl mx-auto bg-white p-6 rounded-lg shadow">
        <div className="text-center text-red-600">Job not found: {jobId}</div>
      </div>
    );
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'queued': return 'text-yellow-600 bg-yellow-50';
      case 'running': return 'text-blue-600 bg-blue-50';
      case 'completed': return 'text-green-600 bg-green-50';
      case 'failed': return 'text-red-600 bg-red-50';
      default: return 'text-gray-600 bg-gray-50';
    }
  };

  return (
    <div className="max-w-2xl mx-auto bg-white p-6 rounded-lg shadow">
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-xl font-bold">Job Status</h2>
        {onClose && (
          <button onClick={onClose} className="text-gray-500 hover:text-gray-700">
            Close
          </button>
        )}
      </div>
      
      <div className="space-y-4">
        <div>
          <strong>Job ID:</strong> <code className="bg-gray-100 px-2 py-1 rounded">{jobId}</code>
        </div>
        
        <div className={`p-3 rounded ${getStatusColor(job.status)}`}>
          <strong>Status:</strong> {job.status}
        </div>
        
        {job.created_at && (
          <div>
            <strong>Created:</strong> {new Date(job.created_at).toLocaleString()}
          </div>
        )}
        
        {job.error_message && (
          <div className="p-3 bg-red-50 border border-red-200 rounded">
            <strong>Error:</strong> {job.error_message}
          </div>
        )}
        
        {job.terraform_output && (
          <div className="p-3 bg-green-50 border border-green-200 rounded">
            <strong>Output:</strong>
            <pre className="text-sm mt-2">{JSON.stringify(job.terraform_output, null, 2)}</pre>
          </div>
        )}
      </div>
    </div>
  );
};
