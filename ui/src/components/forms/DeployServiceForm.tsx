import React, { useState } from 'react';

interface DeployServiceFormProps {
  onSuccess?: (jobId: string) => void;
  onError?: (error: string) => void;
  onSubmit?: () => void;
  onCancel?: () => void;
}

export const DeployServiceForm = ({ onSuccess, onError }: DeployServiceFormProps) => {
  const [formData, setFormData] = useState({
    serviceName: '',
    repoUrl: '',
    environment: 'dev' as 'dev' | 'staging' | 'prod',
    language: '',
  });

  const [isLoading, setIsLoading] = useState(false);
  const [jobId, setJobId] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    
    try {
      // Simulate API call
      const response = await fetch('/api/v1/create-infra', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          resource_type: 'web_app',
          name: formData.serviceName,
          environment: formData.environment,
          region: 'us-east-1',
          config: {
            repo_url: formData.repoUrl,
            language: formData.language,
          },
          tags: { CreatedBy: 'UI' },
        }),
      });

      if (!response.ok) throw new Error('Deployment failed');
      
      const result = await response.json();
      setJobId(result.job_id);
      
      if (onSuccess) onSuccess(result.job_id);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      if (onError) onError(message);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="max-w-md mx-auto bg-white p-6 rounded-lg shadow">
      <h2 className="text-xl font-bold mb-4">Deploy Service</h2>
      
      {jobId && (
        <div className="mb-4 p-3 bg-green-100 border border-green-300 rounded">
          Job created: {jobId}
        </div>
      )}
      
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block mb-1">Service Name</label>
          <input
            type="text"
            value={formData.serviceName}
            onChange={(e) => setFormData({...formData, serviceName: e.target.value})}
            className="w-full p-2 border rounded"
            required
          />
        </div>
        
        <div>
          <label className="block mb-1">Repository URL</label>
          <input
            type="url"
            value={formData.repoUrl}
            onChange={(e) => setFormData({...formData, repoUrl: e.target.value})}
            className="w-full p-2 border rounded"
            required
          />
        </div>
        
        <div>
          <label className="block mb-1">Language</label>
          <select
            value={formData.language}
            onChange={(e) => setFormData({...formData, language: e.target.value})}
            className="w-full p-2 border rounded"
            required
          >
            <option value="">Select Language</option>
            <option value="node">Node.js</option>
            <option value="python">Python</option>
          </select>
        </div>
        
        <button
          type="submit"
          disabled={isLoading}
          className="w-full bg-blue-500 text-white p-2 rounded disabled:opacity-50"
        >
          {isLoading ? 'Deploying...' : 'Deploy'}
        </button>
      </form>
    </div>
  );
};
