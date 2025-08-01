import React, { useState } from 'react';

interface SirwanTestS3FormProps {
  onSuccess?: (jobId: string) => void;
  onError?: (error: string) => void;
  onSubmit?: () => void;
  onCancel?: () => void;
  isAdmin?: boolean; // Add admin prop
}

export const SirwanTestS3Form: React.FC<SirwanTestS3FormProps> = ({ onSuccess, onError, isAdmin = false }) => {
  const [formData, setFormData] = useState({
    bucketName: '',
    environment: 'dev' as 'dev' | 'staging' | 'prod',
    bucketPurpose: 'test-storage',
    versioningEnabled: true,
    encryptionEnabled: true,
    publicReadAccess: false,
    websiteEnabled: false,
    corsEnabled: false,
    lifecycleEnabled: true,
    backupEnabled: false,
    accessLoggingEnabled: false,
    forceDestroy: false,
    // EC2 Configuration - Now properly exposed
    ec2Enabled: false,
    ec2InstanceType: 't3.micro' as 't3.micro' | 't3.small' | 't3.medium' | 't3.large',
    ec2Purpose: 's3-processor',
    ec2KeyName: '',
    ec2EnableS3Integration: true,
    ec2RootVolumeSize: 20,
    ec2MonitoringEnabled: true,
    ec2CloudwatchLogsEnabled: false,
    ec2EnableElasticIp: false,
  });

  const [isLoading, setIsLoading] = useState(false);
  const [jobId, setJobId] = useState<string>('');
  const [deploymentFailed, setDeploymentFailed] = useState(false);
  const [deploymentError, setDeploymentError] = useState<string>('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // Basic validation only
    if (!formData.bucketName.trim()) {
      if (onError) onError('Bucket name is required');
      return;
    }
    
    setIsLoading(true);
    setDeploymentFailed(false);
    setDeploymentError('');
    
    try {
      // For developer workflow: Store request locally and notify admin
      // Generate a request ID for tracking
      const requestId = `REQ-${Date.now()}`;
      
      // Store request in localStorage for admin to review
      const requestData = {
        id: requestId,
        request_type: 's3_bucket',
        title: `S3 Bucket: ${formData.bucketName}`,
        description: `Request for S3 bucket '${formData.bucketName}' in ${formData.environment} environment with${formData.ec2Enabled ? '' : 'out'} EC2 integration`,
        configuration: formData,
        estimated_cost: parseFloat(calculateTotalCost()),
        requested_by: 'developer-user', // In real app, get from auth
        requester_role: 'developer',
        status: 'pending',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      };

      // Store in localStorage (in real app, this would be sent to admin notification system)
      const existingRequests = JSON.parse(localStorage.getItem('pending-requests') || '[]');
      existingRequests.push(requestData);
      localStorage.setItem('pending-requests', JSON.stringify(existingRequests));
      
      // Simulate sending notification to admin (in real app, this could be email, Slack, etc.)
      console.log('Request sent to admin for approval:', requestData);
      
      setJobId(requestId);
      if (onSuccess) onSuccess(requestId);
      
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      setDeploymentFailed(true);
      setDeploymentError(message);
      if (onError) onError(message);
    } finally {
      setIsLoading(false);
    }
  };

  const handleInputChange = (field: string, value: any) => {
    setFormData(prev => ({ ...prev, [field]: value }));
    
    // Reset deployment state when bucket name changes
    if (field === 'bucketName') {
      setJobId('');
      setDeploymentFailed(false);
      setDeploymentError('');
    }
  };

  const calculateTotalCost = () => {
    let total = 1.0; // Base S3 costs
    if (formData.backupEnabled) total += 2.0;
    if (formData.accessLoggingEnabled) total += 1.0;
    
    if (formData.ec2Enabled) {
      // EC2 instance cost
      const instanceCosts = {
        't3.micro': 8.50,
        't3.small': 17.00,
        't3.medium': 34.00,
        't3.large': 67.00
      };
      total += instanceCosts[formData.ec2InstanceType] || 8.50;
      
      // EBS storage
      total += formData.ec2RootVolumeSize * 0.10;
      
      // Additional services
      if (formData.ec2EnableElasticIp) total += 3.60;
      if (formData.ec2MonitoringEnabled) total += 2.10;
      if (formData.ec2CloudwatchLogsEnabled) total += 1.0;
    }
    
    return total.toFixed(2);
  };

  const resetForm = () => {
    setFormData({
      bucketName: '',
      environment: 'dev',
      bucketPurpose: 'test-storage',
      versioningEnabled: true,
      encryptionEnabled: true,
      publicReadAccess: false,
      websiteEnabled: false,
      corsEnabled: false,
      lifecycleEnabled: true,
      backupEnabled: false,
      accessLoggingEnabled: false,
      forceDestroy: false,
      ec2Enabled: false,
      ec2InstanceType: 't3.micro',
      ec2Purpose: 's3-processor',
      ec2KeyName: '',
      ec2EnableS3Integration: true,
      ec2RootVolumeSize: 20,
      ec2MonitoringEnabled: true,
      ec2CloudwatchLogsEnabled: false,
      ec2EnableElasticIp: false,
    });
    setJobId('');
    setDeploymentFailed(false);
    setDeploymentError('');
  };

  return (
    <div className="max-w-4xl mx-auto bg-white p-6 rounded-lg shadow-lg">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-2">
          🚀 Sirwan Test Template - S3 + Optional EC2
        </h2>
        <p className="text-gray-600">
          Create an advanced S3 bucket with comprehensive configuration options including 
          lifecycle management, backup, optional website hosting, and optional EC2 instance
          with automatic S3 integration.
        </p>
      </div>
      
      {jobId && (
        <div className="mb-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
          <div className="flex items-center">
            <div className="text-blue-400 mr-3">📋</div>
            <div className="flex-1">
              <h4 className="font-medium text-blue-800">Request Sent to Admin!</h4>
              <p className="text-blue-700 text-sm">Request ID: {jobId}</p>
              <p className="text-blue-600 text-xs mt-1">
                📋 Your request has been sent to the admin team for review and approval. You'll be notified once it's processed.
              </p>
              
              {isAdmin && (
                <div className="mt-3 pt-3 border-t border-blue-200">
                  <p className="text-sm font-medium text-blue-800 mb-2">Admin Actions:</p>
                  <div className="space-y-2">
                    <div className="flex space-x-2">
                      <button 
                        className="px-3 py-1 bg-green-600 text-white text-xs rounded hover:bg-green-700"
                        onClick={() => window.open(`/admin/requests/${jobId}`, '_blank')}
                      >
                        Review Request
                      </button>
                      <button 
                        className="px-3 py-1 bg-blue-600 text-white text-xs rounded hover:bg-blue-700"
                        onClick={() => window.open('/admin/pending-requests', '_blank')}
                      >
                        View All Pending
                      </button>
                    </div>
                    <div className="text-xs text-blue-700">
                      <div className="flex justify-between">
                        <span>Status:</span>
                        <span className="font-mono bg-blue-100 px-2 py-1 rounded">PENDING APPROVAL</span>
                      </div>
                      <div className="flex justify-between mt-1">
                        <span>Created:</span>
                        <span className="font-mono">{new Date().toLocaleString()}</span>
                      </div>
                    </div>
                  </div>
                  <p className="text-xs text-blue-600 mt-2">
                    * Admin controls are only visible to administrators
                  </p>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {deploymentFailed && !jobId && (
        <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
          <div className="flex items-center">
            <div className="text-red-400 mr-3">❌</div>
            <div className="flex-1">
              <h4 className="font-medium text-red-800">Request Submission Failed</h4>
              {isAdmin ? (
                <div className="mt-2 space-y-2">
                  <p className="text-red-700 text-sm">
                    Technical Details (Admin View):
                  </p>
                  {deploymentError && (
                    <pre className="bg-red-100 p-3 rounded text-xs text-red-800 overflow-x-auto border">
                      {deploymentError}
                    </pre>
                  )}
                  <p className="text-red-700 text-sm">
                    You can retry submitting the request or check the API service status.
                  </p>
                  <p className="text-xs text-red-600">
                    * Detailed error information is only visible to administrators
                  </p>
                </div>
              ) : (
                <div className="mt-2">
                  <p className="text-red-700 text-sm">
                    There was an issue submitting your request. Please try again or contact your platform team for assistance.
                  </p>
                  <p className="text-xs text-red-600 mt-2">
                    Error ID: REQ-{Date.now().toString().slice(-6)} - Quote this when contacting support
                  </p>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
      
      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Basic Configuration */}
        <div className="border border-gray-200 rounded-lg p-4">
          <h3 className="text-lg font-semibold mb-4 text-gray-900 flex items-center">
            📋 Basic Configuration
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="md:col-span-2">
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Bucket Name *
              </label>
              <input
                type="text"
                value={formData.bucketName}
                onChange={(e) => handleInputChange('bucketName', e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                placeholder="sirwan-v23"
                required
              />
              <p className="text-xs text-gray-500 mt-1">
                💡 Name validation will be performed by admin during approval process
              </p>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Environment *
              </label>
              <select
                value={formData.environment}
                onChange={(e) => handleInputChange('environment', e.target.value as 'dev' | 'staging' | 'prod')}
                className="w-full p-3 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                required
              >
                <option value="dev">Development</option>
                <option value="staging">Staging</option>
                <option value="prod">Production</option>
              </select>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Bucket Purpose
              </label>
              <select
                value={formData.bucketPurpose}
                onChange={(e) => handleInputChange('bucketPurpose', e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="test-storage">Test Storage</option>
                <option value="static-website">Static Website</option>
                <option value="data-storage">Data Storage</option>
                <option value="backup">Backup Storage</option>
                <option value="media-storage">Media Storage</option>
                <option value="document-storage">Document Storage</option>
              </select>
            </div>
          </div>
        </div>

        {/* Security Configuration */}
        <div className="border border-gray-200 rounded-lg p-4">
          <h3 className="text-lg font-semibold mb-4 text-gray-900">🔒 Security Configuration</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="flex items-center">
              <input
                type="checkbox"
                id="versioning"
                checked={formData.versioningEnabled}
                onChange={(e) => handleInputChange('versioningEnabled', e.target.checked)}
                className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label htmlFor="versioning" className="ml-2 text-sm text-gray-700">
                Enable Versioning
              </label>
            </div>
            
            <div className="flex items-center">
              <input
                type="checkbox"
                id="encryption"
                checked={formData.encryptionEnabled}
                onChange={(e) => handleInputChange('encryptionEnabled', e.target.checked)}
                className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label htmlFor="encryption" className="ml-2 text-sm text-gray-700">
                Server-side Encryption
              </label>
            </div>

            <div className="flex items-center">
              <input
                type="checkbox"
                id="publicRead"
                checked={formData.publicReadAccess}
                onChange={(e) => handleInputChange('publicReadAccess', e.target.checked)}
                className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label htmlFor="publicRead" className="ml-2 text-sm text-gray-700">
                Public Read Access ⚠️
              </label>
            </div>

            <div className="flex items-center">
              <input
                type="checkbox"
                id="forceDestroy"
                checked={formData.forceDestroy}
                onChange={(e) => handleInputChange('forceDestroy', e.target.checked)}
                className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label htmlFor="forceDestroy" className="ml-2 text-sm text-gray-700">
                Force Destroy (⚠️ Testing Only)
              </label>
            </div>
          </div>
        </div>

        {/* EC2 Configuration Section */}
        <div className="border border-gray-200 rounded-lg p-4">
          <div className="flex items-center mb-4">
            <input
              type="checkbox"
              id="ec2Enabled"
              checked={formData.ec2Enabled}
              onChange={(e) => handleInputChange('ec2Enabled', e.target.checked)}
              className="h-5 w-5 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
            />
            <label htmlFor="ec2Enabled" className="ml-3">
              <h3 className="text-lg font-semibold text-gray-900">
                🖥️ Optional EC2 Instance Configuration
              </h3>
              <p className="text-sm text-gray-600">
                Deploy an EC2 instance with automatic S3 integration for processing or management tasks
              </p>
            </label>
          </div>

          {formData.ec2Enabled && (
            <div className="mt-4 p-4 bg-blue-50 border border-blue-200 rounded-lg space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Instance Type
                  </label>
                  <select
                    value={formData.ec2InstanceType}
                    onChange={(e) => handleInputChange('ec2InstanceType', e.target.value as typeof formData.ec2InstanceType)}
                    className="w-full p-3 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500"
                  >
                    <option value="t3.micro">t3.micro (1 vCPU, 1 GB RAM) - $8.50/month</option>
                    <option value="t3.small">t3.small (2 vCPU, 2 GB RAM) - $17/month</option>
                    <option value="t3.medium">t3.medium (2 vCPU, 4 GB RAM) - $34/month</option>
                    <option value="t3.large">t3.large (2 vCPU, 8 GB RAM) - $67/month</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Root Volume Size (GB)
                  </label>
                  <input
                    type="number"
                    min="8"
                    max="100"
                    value={formData.ec2RootVolumeSize}
                    onChange={(e) => handleInputChange('ec2RootVolumeSize', parseInt(e.target.value) || 20)}
                    className="w-full p-3 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500"
                  />
                  <p className="text-xs text-gray-500 mt-1">${(formData.ec2RootVolumeSize * 0.10).toFixed(2)}/month</p>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Instance Purpose
                  </label>
                  <input
                    type="text"
                    value={formData.ec2Purpose}
                    onChange={(e) => handleInputChange('ec2Purpose', e.target.value)}
                    className="w-full p-3 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500"
                    placeholder="s3-processor"
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Key Pair Name (Optional)
                  </label>
                  <input
                    type="text"
                    value={formData.ec2KeyName}
                    onChange={(e) => handleInputChange('ec2KeyName', e.target.value)}
                    className="w-full p-3 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500"
                    placeholder="my-key-pair"
                  />
                  <p className="text-xs text-gray-500 mt-1">Leave empty to create instance without SSH access</p>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="flex items-center">
                  <input
                    type="checkbox"
                    id="ec2S3Integration"
                    checked={formData.ec2EnableS3Integration}
                    onChange={(e) => handleInputChange('ec2EnableS3Integration', e.target.checked)}
                    className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                  />
                  <label htmlFor="ec2S3Integration" className="ml-2 text-sm text-gray-700">
                    Enable S3 Integration (IAM Role)
                  </label>
                </div>

                <div className="flex items-center">
                  <input
                    type="checkbox"
                    id="ec2Monitoring"
                    checked={formData.ec2MonitoringEnabled}
                    onChange={(e) => handleInputChange('ec2MonitoringEnabled', e.target.checked)}
                    className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                  />
                  <label htmlFor="ec2Monitoring" className="ml-2 text-sm text-gray-700">
                    Detailed Monitoring (+$2.10/month)
                  </label>
                </div>

                <div className="flex items-center">
                  <input
                    type="checkbox"
                    id="ec2CloudwatchLogs"
                    checked={formData.ec2CloudwatchLogsEnabled}
                    onChange={(e) => handleInputChange('ec2CloudwatchLogsEnabled', e.target.checked)}
                    className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                  />
                  <label htmlFor="ec2CloudwatchLogs" className="ml-2 text-sm text-gray-700">
                    CloudWatch Logs Agent
                  </label>
                </div>

                <div className="flex items-center">
                  <input
                    type="checkbox"
                    id="ec2ElasticIp"
                    checked={formData.ec2EnableElasticIp}
                    onChange={(e) => handleInputChange('ec2EnableElasticIp', e.target.checked)}
                    className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                  />
                  <label htmlFor="ec2ElasticIp" className="ml-2 text-sm text-gray-700">
                    Allocate Elastic IP (+$3.60/month)
                  </label>
                </div>
              </div>

              <div className="mt-4 p-3 bg-yellow-50 border border-yellow-200 rounded">
                <p className="text-yellow-800 text-sm">
                  ⚠️ <strong>EC2 Security Note:</strong> Instance will be launched in the default VPC with a security group 
                  allowing SSH (port 22) and HTTP/HTTPS (ports 80, 443). Review security settings after deployment.
                </p>
              </div>
            </div>
          )}
        </div>

        {/* Cost Estimation */}
        <div className="border border-gray-200 rounded-lg p-4 bg-gray-50">
          <h3 className="text-lg font-semibold mb-2 text-gray-900">💰 Estimated Monthly Cost</h3>
          <div className="text-sm text-gray-600 space-y-1">
            <div className="font-medium text-gray-900 mb-2">S3 Storage Costs:</div>
            <p>• Storage: $0.023 per GB/month (first 50 TB)</p>
            <p>• Requests: $0.0004-0.0005 per 1,000 requests</p>
            {formData.backupEnabled && <p>• Backup storage: $0.004-0.0125 per GB (depending on storage class)</p>}
            {formData.accessLoggingEnabled && <p>• CloudWatch logs: $0.50 per GB ingested</p>}
            
            {formData.ec2Enabled && (
              <>
                <div className="font-medium text-gray-900 mt-3 mb-2">EC2 Instance Costs:</div>
                <p>• Instance ({formData.ec2InstanceType}): {
                  formData.ec2InstanceType === 't3.micro' ? '$8.50' :
                  formData.ec2InstanceType === 't3.small' ? '$17.00' :
                  formData.ec2InstanceType === 't3.medium' ? '$34.00' :
                  formData.ec2InstanceType === 't3.large' ? '$67.00' : '$8.50'
                }/month</p>
                <p>• EBS Storage ({formData.ec2RootVolumeSize} GB): ${(formData.ec2RootVolumeSize * 0.10).toFixed(2)}/month</p>
                {formData.ec2EnableElasticIp && <p>• Elastic IP: $3.60/month</p>}
                {formData.ec2MonitoringEnabled && <p>• Detailed Monitoring: $2.10/month</p>}
                {formData.ec2CloudwatchLogsEnabled && <p>• CloudWatch Logs: $0.50/GB ingested</p>}
              </>
            )}
            
            <div className="border-t pt-2 mt-3">
              <p className="font-medium text-gray-900">
                Total estimate: ${calculateTotalCost()}/month (estimated)
              </p>
              <p className="text-xs text-gray-500 mt-1">
                * Costs may vary based on actual usage, data transfer, and additional AWS services
              </p>
            </div>
          </div>
        </div>

        {/* Submit Button */}
        <div className="flex space-x-4">
          <button
            type="submit"
            disabled={
              isLoading || 
              !formData.bucketName.trim() || 
              (!!jobId && !deploymentFailed) // Disable if request already submitted
            }
            className="flex-1 bg-blue-600 text-white py-3 px-6 rounded-md font-medium hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {isLoading ? (
              <div className="flex items-center justify-center">
                <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Submitting Request...
              </div>
            ) : jobId && !deploymentFailed ? (
              '✅ Request Submitted for Approval'
            ) : deploymentFailed ? (
              '🔄 Retry Submit Request'
            ) : (
              '� Submit Request for S3 Bucket'
            )}
          </button>
          
          <button
            type="button"
            className="px-6 py-3 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50 transition-colors"
            onClick={resetForm}
          >
            Reset
          </button>
        </div>
      </form>
    </div>
  );
};

export default SirwanTestS3Form;
