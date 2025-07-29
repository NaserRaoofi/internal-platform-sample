"""
Utility Functions - Helper functions and utilities
===============================================

Production-grade utility functions for the platform.
"""

import os
import uuid
import hashlib
import json
from datetime import datetime
from typing import Dict, Any, Optional, List
import logging

logger = logging.getLogger(__name__)

def generate_job_id() -> str:
    """Generate unique job ID"""
    return str(uuid.uuid4())

def generate_short_id(length: int = 8) -> str:
    """Generate short unique ID"""
    return str(uuid.uuid4()).replace('-', '')[:length]

def hash_config(config: Dict[str, Any]) -> str:
    """Generate hash for configuration"""
    config_str = json.dumps(config, sort_keys=True)
    return hashlib.sha256(config_str.encode()).hexdigest()[:16]

def sanitize_resource_name(name: str) -> str:
    """Sanitize resource name for AWS/Terraform compatibility"""
    # Replace invalid characters with hyphens
    sanitized = ''.join(c if c.isalnum() else '-' for c in name.lower())
    
    # Remove consecutive hyphens
    while '--' in sanitized:
        sanitized = sanitized.replace('--', '-')
    
    # Remove leading/trailing hyphens
    sanitized = sanitized.strip('-')
    
    # Ensure it starts with a letter
    if sanitized and not sanitized[0].isalpha():
        sanitized = f"res-{sanitized}"
    
    # Limit length
    if len(sanitized) > 50:
        sanitized = sanitized[:47] + generate_short_id(3)
    
    return sanitized or "resource"

def validate_aws_region(region: str) -> bool:
    """Validate AWS region format"""
    valid_regions = [
        'us-east-1', 'us-east-2', 'us-west-1', 'us-west-2',
        'eu-north-1', 'eu-west-1', 'eu-west-2', 'eu-west-3', 'eu-central-1',
        'ap-northeast-1', 'ap-northeast-2', 'ap-southeast-1', 'ap-southeast-2',
        'ap-south-1', 'sa-east-1', 'ca-central-1'
    ]
    return region in valid_regions

def validate_environment(environment: str) -> bool:
    """Validate environment name"""
    valid_environments = ['dev', 'staging', 'prod', 'test']
    return environment.lower() in valid_environments

def format_terraform_output(output: Dict[str, Any]) -> Dict[str, str]:
    """Format Terraform output for display"""
    formatted = {}
    
    for key, value in output.items():
        if isinstance(value, dict) and 'value' in value:
            # Standard terraform output format
            formatted[key] = str(value['value'])
        else:
            formatted[key] = str(value)
    
    return formatted

def mask_sensitive_data(data: Dict[str, Any], sensitive_keys: Optional[List[str]] = None) -> Dict[str, Any]:
    """Mask sensitive information in configuration"""
    if sensitive_keys is None:
        sensitive_keys = [
            'password', 'secret', 'key', 'token', 'api_key',
            'access_key', 'secret_key', 'private_key', 'certificate'
        ]
    
    masked_data = data.copy()
    
    def mask_recursive(obj):
        if isinstance(obj, dict):
            for key, value in obj.items():
                if any(sensitive in key.lower() for sensitive in sensitive_keys):
                    obj[key] = "***MASKED***"
                elif isinstance(value, (dict, list)):
                    mask_recursive(value)
        elif isinstance(obj, list):
            for item in obj:
                if isinstance(item, (dict, list)):
                    mask_recursive(item)
    
    mask_recursive(masked_data)
    return masked_data

def calculate_estimated_duration(resource_type: str, action: str) -> int:
    """Calculate estimated job duration in seconds"""
    durations = {
        'ec2': {'create': 300, 'destroy': 180, 'update': 240},
        's3': {'create': 60, 'destroy': 120, 'update': 90},
        'vpc': {'create': 180, 'destroy': 240, 'update': 200},
        'rds': {'create': 900, 'destroy': 600, 'update': 720},
        'web_app': {'create': 1200, 'destroy': 600, 'update': 900},
        'api_service': {'create': 800, 'destroy': 400, 'update': 600}
    }
    
    return durations.get(resource_type, {}).get(action, 300)

def parse_terraform_error(error_output: str) -> Dict[str, Any]:
    """Parse Terraform error output for better error reporting"""
    error_info = {
        'type': 'unknown',
        'message': error_output,
        'suggestions': []
    }
    
    error_lower = error_output.lower()
    
    if 'authentication' in error_lower or 'access denied' in error_lower:
        error_info['type'] = 'authentication'
        error_info['suggestions'] = [
            'Check AWS credentials configuration',
            'Verify IAM permissions',
            'Ensure AWS CLI is properly configured'
        ]
    elif 'already exists' in error_lower:
        error_info['type'] = 'resource_conflict'
        error_info['suggestions'] = [
            'Resource with this name already exists',
            'Try a different resource name',
            'Check if resource was created outside Terraform'
        ]
    elif 'not found' in error_lower:
        error_info['type'] = 'resource_not_found'
        error_info['suggestions'] = [
            'Resource may have been deleted outside Terraform',
            'Check resource configuration',
            'Verify resource exists in the specified region'
        ]
    elif 'invalid' in error_lower or 'validation' in error_lower:
        error_info['type'] = 'validation'
        error_info['suggestions'] = [
            'Check configuration parameters',
            'Verify resource specifications',
            'Review AWS service limits'
        ]
    elif 'timeout' in error_lower:
        error_info['type'] = 'timeout'
        error_info['suggestions'] = [
            'Operation timed out - this may be temporary',
            'Try running the operation again',
            'Check AWS service status'
        ]
    
    return error_info

def format_duration(seconds: int) -> str:
    """Format duration in human-readable format"""
    if seconds < 60:
        return f"{seconds}s"
    elif seconds < 3600:
        minutes = seconds // 60
        remaining_seconds = seconds % 60
        return f"{minutes}m {remaining_seconds}s"
    else:
        hours = seconds // 3600
        remaining_minutes = (seconds % 3600) // 60
        return f"{hours}h {remaining_minutes}m"

def get_terraform_version() -> Optional[str]:
    """Get installed Terraform version"""
    try:
        import subprocess
        result = subprocess.run(
            ['terraform', 'version'],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode == 0:
            # Parse version from output like "Terraform v1.0.0"
            lines = result.stdout.split('\n')
            for line in lines:
                if line.startswith('Terraform v'):
                    return line.split(' ')[1]
        
        return None
    except Exception as e:
        logger.warning(f"Failed to get Terraform version: {str(e)}")
        return None

def create_backup_name(original_name: str) -> str:
    """Create backup name with timestamp"""
    timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
    return f"{original_name}_backup_{timestamp}"

def validate_json_config(config_str: str) -> tuple[bool, Optional[Dict], Optional[str]]:
    """Validate JSON configuration string"""
    try:
        config = json.loads(config_str)
        return True, config, None
    except json.JSONDecodeError as e:
        return False, None, str(e)

def safe_dict_get(data: Dict[str, Any], path: str, default: Any = None) -> Any:
    """Safely get nested dictionary value using dot notation"""
    try:
        keys = path.split('.')
        value = data
        
        for key in keys:
            if isinstance(value, dict) and key in value:
                value = value[key]
            else:
                return default
        
        return value
    except Exception:
        return default

def merge_configs(base_config: Dict[str, Any], override_config: Dict[str, Any]) -> Dict[str, Any]:
    """Deep merge two configuration dictionaries"""
    result = base_config.copy()
    
    for key, value in override_config.items():
        if (key in result and 
            isinstance(result[key], dict) and 
            isinstance(value, dict)):
            result[key] = merge_configs(result[key], value)
        else:
            result[key] = value
    
    return result
