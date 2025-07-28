import React from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../ui/card';
import { Button } from '../ui/button';
import { Input } from '../ui/input';
import { Label } from '../ui/label';
import { useAppStore } from '../../store/appStore';

// Validation schema
const deployServiceSchema = z.object({
  serviceName: z.string()
    .min(3, 'Service name must be at least 3 characters')
    .max(50, 'Service name must be less than 50 characters')
    .regex(/^[a-z0-9-]+$/, 'Service name must contain only lowercase letters, numbers, and hyphens'),
  repoUrl: z.string()
    .url('Please enter a valid repository URL')
    .regex(/^https:\/\/github\.com\//, 'Only GitHub repositories are supported'),
  environment: z.enum(['development', 'staging', 'production']),
  language: z.enum(['nodejs', 'python', 'go', 'java', 'dotnet', 'ruby']),
  enableDatabase: z.boolean(),
  enableMonitoring: z.boolean(),
});

type DeployServiceFormData = z.infer<typeof deployServiceSchema>;

interface DeployServiceFormProps {
  onSubmit?: (data: DeployServiceFormData) => void;
  onCancel?: () => void;
}

export function DeployServiceForm({ onSubmit, onCancel }: DeployServiceFormProps) {
  const { submitRequest, loading } = useAppStore();
  const [isSubmitting, setIsSubmitting] = React.useState(false);

  const {
    register,
    handleSubmit,
    formState: { errors },
    reset,
    watch,
  } = useForm<DeployServiceFormData>({
    resolver: zodResolver(deployServiceSchema),
    defaultValues: {
      serviceName: '',
      repoUrl: '',
      environment: 'development',
      language: 'nodejs',
      enableDatabase: false,
      enableMonitoring: true,
    },
  });

  const watchedValues = watch();

  const onFormSubmit = async (data: DeployServiceFormData) => {
    setIsSubmitting(true);
    
    try {
      // Call the backend API
      const response = await fetch('/api/deploy', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          service_name: data.serviceName,
          repo_url: data.repoUrl,
          environment: data.environment,
          language: data.language,
          enable_database: data.enableDatabase,
          enable_monitoring: data.enableMonitoring,
        }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail || 'Failed to deploy service');
      }

      const result = await response.json();
      
      alert(`✅ Deployment Initiated - Service "${data.serviceName}" deployment has been queued. Request ID: ${result.request_id}`);

      // Reset form and call onSubmit callback
      reset();
      onSubmit?.(data);
      
    } catch (error) {
      console.error('Deployment error:', error);
      alert(`❌ Deployment Failed - ${error instanceof Error ? error.message : "An unexpected error occurred"}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Card className="w-full max-w-2xl mx-auto">
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <span className="text-2xl">🚀</span>
          Deploy New Service
        </CardTitle>
        <CardDescription>
          Deploy a new service to your chosen environment. Fill out the form below to get started.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit(onFormSubmit)} className="space-y-6">
          {/* Service Name */}
          <div className="space-y-2">
            <Label htmlFor="serviceName">Service Name *</Label>
            <Input
              id="serviceName"
              {...register('serviceName')}
              placeholder="my-awesome-service"
              className={errors.serviceName ? 'border-red-500' : ''}
            />
            {errors.serviceName && (
              <p className="text-sm text-red-600">{errors.serviceName.message}</p>
            )}
          </div>

          {/* Repository URL */}
          <div className="space-y-2">
            <Label htmlFor="repoUrl">Repository URL *</Label>
            <Input
              id="repoUrl"
              {...register('repoUrl')}
              placeholder="https://github.com/username/repository"
              className={errors.repoUrl ? 'border-red-500' : ''}
            />
            {errors.repoUrl && (
              <p className="text-sm text-red-600">{errors.repoUrl.message}</p>
            )}
          </div>

          {/* Environment Selection */}
          <div className="space-y-2">
            <Label htmlFor="environment">Environment *</Label>
            <select
              id="environment"
              {...register('environment')}
              className="flex h-10 w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2"
            >
              <option value="development">Development</option>
              <option value="staging">Staging</option>
              <option value="production">Production</option>
            </select>
          </div>

          {/* Language Selection */}
          <div className="space-y-2">
            <Label htmlFor="language">Language/Runtime *</Label>
            <select
              id="language"
              {...register('language')}
              className="flex h-10 w-full rounded-md border border-gray-300 bg-white px-3 py-2 text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2"
            >
              <option value="nodejs">Node.js</option>
              <option value="python">Python</option>
              <option value="go">Go</option>
              <option value="java">Java</option>
              <option value="dotnet">.NET</option>
              <option value="ruby">Ruby</option>
            </select>
          </div>

          {/* Feature Toggles */}
          <div className="space-y-4">
            <div className="flex items-center space-x-2">
              <input
                type="checkbox"
                id="enableDatabase"
                {...register('enableDatabase')}
                className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary"
              />
              <Label htmlFor="enableDatabase" className="text-sm font-normal">
                Enable Database (PostgreSQL)
              </Label>
            </div>

            <div className="flex items-center space-x-2">
              <input
                type="checkbox"
                id="enableMonitoring"
                {...register('enableMonitoring')}
                className="h-4 w-4 rounded border-gray-300 text-primary focus:ring-primary"
              />
              <Label htmlFor="enableMonitoring" className="text-sm font-normal">
                Enable Monitoring & Alerting
              </Label>
            </div>
          </div>

          {/* Preview Section */}
          <div className="p-4 bg-gray-100 rounded-lg">
            <h4 className="text-sm font-medium mb-2">Deployment Preview:</h4>
            <div className="text-sm text-gray-600 space-y-1">
              <p>Service: <span className="font-mono">{watchedValues.serviceName || 'my-awesome-service'}</span></p>
              <p>Environment: <span className="font-mono">{watchedValues.environment}</span></p>
              <p>Runtime: <span className="font-mono">{watchedValues.language}</span></p>
              <p>Database: <span className="font-mono">{watchedValues.enableDatabase ? 'Enabled' : 'Disabled'}</span></p>
              <p>Monitoring: <span className="font-mono">{watchedValues.enableMonitoring ? 'Enabled' : 'Disabled'}</span></p>
            </div>
          </div>

          {/* Form Actions */}
          <div className="flex gap-3 pt-4">
            <Button
              type="submit"
              disabled={isSubmitting}
              className="flex-1"
            >
              {isSubmitting ? (
                <>
                  <span className="animate-spin mr-2">⏳</span>
                  Deploying...
                </>
              ) : (
                <>
                  <span className="mr-2">🚀</span>
                  Deploy Service
                </>
              )}
            </Button>
            {onCancel && (
              <Button
                type="button"
                variant="outline"
                onClick={onCancel}
                disabled={isSubmitting}
              >
                Cancel
              </Button>
            )}
          </div>
        </form>
      </CardContent>
    </Card>
  );
}
