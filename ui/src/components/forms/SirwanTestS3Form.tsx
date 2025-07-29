import React, { useState } from 'react';
import { createSirwanTestS3 } from '../../services/apiClient';

interface SirwanTestS3FormProps {
  onSuccess?: (jobId: string) => void;
  onError?: (error: string) => void;
  onSubmit?: () => void;
  onCancel?: () => void;
}

export const SirwanTestS3Form = ({ onSuccess, onError }: SirwanTestS3FormProps) => {
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
    // EC2 Configuration
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

  const [isLoading, setIsLoading] = useState(false);
  const [jobId, setJobId] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    
    try {
      const response = await createSirwanTestS3(formData);
      setJobId(response.job_id);
      
      if (onSuccess) onSuccess(response.job_id);
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unknown error';
      if (onError) onError(message);
    } finally {
      setIsLoading(false);
    }
  };

  const handleInputChange = (field: string, value: any) => {
    setFormData(prev => ({ ...prev, [field]: value }));
  };

  return (
    <div className="max-w-2xl mx-auto bg-white p-6 rounded-lg shadow-lg">
      <div className="mb-6">
        <h2 className="text-2xl font-bold text-gray-900 mb-2">🚀 Sirwan Test Template - S3 + EC2</h2>
        <p className="text-gray-600">
          Create an advanced S3 bucket with comprehensive configuration options including 
          lifecycle management, backup, optional website hosting, and optional EC2 instance
          with automatic S3 integration.
        </p>
      </div>
      
      {jobId && (
        <div className="mb-6 p-4 bg-green-50 border border-green-200 rounded-lg">
          <div className="flex items-center">
            <div className="text-green-400 mr-3">✅</div>
            <div>
              <h4 className="font-medium text-green-800">Job Created Successfully!</h4>
              <p className="text-green-700 text-sm">Job ID: {jobId}</p>
            </div>
          </div>
        </div>
      )}
      
      <form onSubmit={handleSubmit} className="space-y-6">
        {/* Basic Configuration */}
        <div className="border border-gray-200 rounded-lg p-4">
          <h3 className="text-lg font-semibold mb-4 text-gray-900">📋 Basic Configuration</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
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
                Lowercase letters, numbers, and hyphens only
              </p>
            </div>
            
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Environment *
              </label>
              <select
                value={formData.environment}
                onChange={(e) => handleInputChange('environment', e.target.value)}
                className="w-full p-3 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                required
              >
                <option value="dev">Development</option>
                <option value="staging">Staging</option>
                <option value="prod">Production</option>
              </select>
            </div>
            
            <div className="md:col-span-2">
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
                Public Read Access
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
                Force Destroy (⚠️ Dangerous)
              </label>
            </div>
          </div>
        </div>

        {/* Website Configuration */}
        <div className="border border-gray-200 rounded-lg p-4">
          <h3 className="text-lg font-semibold mb-4 text-gray-900">🌐 Website & CORS Configuration</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="flex items-center">
              <input
                type="checkbox"
                id="website"
                checked={formData.websiteEnabled}
                onChange={(e) => handleInputChange('websiteEnabled', e.target.checked)}
                className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label htmlFor="website" className="ml-2 text-sm text-gray-700">
                Static Website Hosting
              </label>
            </div>
            
            <div className="flex items-center">
              <input
                type="checkbox"
                id="cors"
                checked={formData.corsEnabled}
                onChange={(e) => handleInputChange('corsEnabled', e.target.checked)}
                className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label htmlFor="cors" className="ml-2 text-sm text-gray-700">
                CORS Configuration
              </label>
            </div>
          </div>
          {(formData.websiteEnabled || formData.corsEnabled) && (
            <div className="mt-3 p-3 bg-blue-50 border border-blue-200 rounded">
              <p className="text-blue-800 text-sm">
                💡 {formData.websiteEnabled ? 'Website hosting will be configured with index.html and error.html.' : ''}
                {formData.corsEnabled ? ' CORS will allow cross-origin requests.' : ''}
              </p>
            </div>
          )}
        </div>

        {/* Advanced Features */}
        <div className="border border-gray-200 rounded-lg p-4">
          <h3 className="text-lg font-semibold mb-4 text-gray-900">⚙️ Advanced Features</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="flex items-center">
              <input
                type="checkbox"
                id="lifecycle"
                checked={formData.lifecycleEnabled}
                onChange={(e) => handleInputChange('lifecycleEnabled', e.target.checked)}
                className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label htmlFor="lifecycle" className="ml-2 text-sm text-gray-700">
                Lifecycle Management
              </label>
            </div>
            
            <div className="flex items-center">
              <input
                type="checkbox"
                id="backup"
                checked={formData.backupEnabled}
                onChange={(e) => handleInputChange('backupEnabled', e.target.checked)}
                className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label htmlFor="backup" className="ml-2 text-sm text-gray-700">
                Backup Bucket
              </label>
            </div>
            
            <div className="flex items-center">
              <input
                type="checkbox"
                id="logging"
                checked={formData.accessLoggingEnabled}
                onChange={(e) => handleInputChange('accessLoggingEnabled', e.target.checked)}
                className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
              />
              <label htmlFor="logging" className="ml-2 text-sm text-gray-700">
                CloudWatch Access Logging
              </label>
            </div>
          </div>
          
          {(formData.lifecycleEnabled || formData.backupEnabled || formData.accessLoggingEnabled) && (
            <div className="mt-3 p-3 bg-green-50 border border-green-200 rounded">
              <p className="text-green-800 text-sm">
                💡 Advanced features help optimize costs and improve monitoring:
              </p>
              <ul className="text-green-700 text-xs mt-1 ml-4">
                {formData.lifecycleEnabled && <li>• Objects will transition to cheaper storage classes automatically</li>}
                {formData.backupEnabled && <li>• Separate backup bucket with 7-year retention policy</li>}
                {formData.accessLoggingEnabled && <li>• CloudWatch logs for access monitoring</li>}
              </ul>
            </div>
          )}
        </div>

        {/* Cost Estimation */}
        <div className="border border-gray-200 rounded-lg p-4 bg-gray-50">
          <h3 className="text-lg font-semibold mb-2 text-gray-900">💰 Estimated Monthly Cost</h3>
          <div className="text-sm text-gray-600 space-y-1">
            <p>• Storage: $0.023 per GB/month (first 50 TB)</p>
            <p>• Requests: $0.0004-0.0005 per 1,000 requests</p>
            {formData.backupEnabled && <p>• Backup storage: $0.004-0.0125 per GB (depending on storage class)</p>}
            {formData.accessLoggingEnabled && <p>• CloudWatch logs: $0.50 per GB ingested</p>}
            <p className="font-medium text-gray-900">
              Total estimate: $0.50 - $5.00/month (depending on usage)
            </p>
          </div>
        </div>

        {/* Submit Button */}
        <div className="flex space-x-4">
          <button
            type="submit"
            disabled={isLoading || !formData.bucketName}
            className="flex-1 bg-blue-600 text-white py-3 px-6 rounded-md font-medium hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {isLoading ? (
              <div className="flex items-center justify-center">
                <svg className="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4"></circle>
                  <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Creating S3 Bucket...
              </div>
            ) : (
              '🚀 Create Sirwan Test S3 Bucket'
            )}
          </button>
          
          <button
            type="button"
            className="px-6 py-3 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50 transition-colors"
            onClick={() => setFormData({
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
              // EC2 Configuration
              ec2Enabled: false,
              ec2InstanceType: 't3.micro',
              ec2Purpose: 's3-processor',
              ec2KeyName: '',
              ec2EnableS3Integration: true,
              ec2RootVolumeSize: 20,
              ec2MonitoringEnabled: true,
              ec2CloudwatchLogsEnabled: false,
              ec2EnableElasticIp: false,
            })}
          >
            Reset
          </button>
        </div>
      </form>
    </div>
  );
};
