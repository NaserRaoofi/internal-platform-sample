"""
Flet UI Application for Internal Developer Platform.

This provides a simple web-based interface for developers to submit
AWS resource provisioning requests.
"""

import json
import requests
import flet as ft
from typing import Dict, Any, Optional


class ProvisioningUI:
    """Main UI class for the provisioning platform."""
    
    def __init__(self, page: ft.Page):
        self.page = page
        self.page.title = "Internal Developer Platform"
        self.page.theme_mode = ft.ThemeMode.LIGHT
        self.page.padding = 20
        
        # API configuration
        self.api_base_url = "http://localhost:8000"
        
        # UI state
        self.current_request_id: Optional[str] = None
        self.status_text = ft.Text("")
        
        self.setup_ui()
    
    def setup_ui(self):
        """Set up the main UI layout."""
        # Header
        header = ft.Container(
            content=ft.Column([
                ft.Text("Internal Developer Platform", size=30, weight=ft.FontWeight.BOLD),
                ft.Text("Provision AWS resources with ease", size=16, color=ft.colors.GREY_700),
                ft.Divider()
            ]),
            margin=ft.margin.only(bottom=20)
        )
        
        # Tabs for different resource types
        tabs = ft.Tabs(
            selected_index=0,
            animation_duration=300,
            tabs=[
                ft.Tab(text="EC2 Instance", content=self.create_ec2_form()),
                ft.Tab(text="VPC", content=self.create_vpc_form()),
                ft.Tab(text="S3 Bucket", content=self.create_s3_form()),
                ft.Tab(text="Request Status", content=self.create_status_form())
            ]
        )
        
        # Status display
        status_container = ft.Container(
            content=ft.Column([
                ft.Divider(),
                ft.Text("Status:", weight=ft.FontWeight.BOLD),
                self.status_text
            ]),
            margin=ft.margin.only(top=20)
        )
        
        # Add all components to page
        self.page.add(header, tabs, status_container)
    
    def create_ec2_form(self) -> ft.Container:
        """Create EC2 provisioning form."""
        # Form fields
        self.ec2_instance_type = ft.TextField(
            label="Instance Type",
            value="t3.micro",
            hint_text="e.g., t3.micro, m5.large"
        )
        
        self.ec2_ami_id = ft.TextField(
            label="AMI ID",
            value="ami-0abcdef1234567890",
            hint_text="Amazon Machine Image ID"
        )
        
        self.ec2_key_pair = ft.TextField(
            label="Key Pair Name",
            value="my-key-pair",
            hint_text="SSH key pair for instance access"
        )
        
        self.ec2_security_groups = ft.TextField(
            label="Security Group IDs (comma-separated)",
            hint_text="sg-123456789abcdef0, sg-987654321fedcba0"
        )
        
        self.ec2_subnet_id = ft.TextField(
            label="Subnet ID (optional)",
            hint_text="subnet-123456789abcdef0"
        )
        
        self.ec2_tags = ft.TextField(
            label="Tags (JSON format)",
            value='{"Environment": "dev", "Project": "test"}',
            multiline=True,
            min_lines=2,
            max_lines=4
        )
        
        submit_button = ft.ElevatedButton(
            text="Submit EC2 Request",
            on_click=self.submit_ec2_request,
            style=ft.ButtonStyle(
                bgcolor=ft.colors.BLUE,
                color=ft.colors.WHITE
            )
        )
        
        return ft.Container(
            content=ft.Column([
                self.ec2_instance_type,
                self.ec2_ami_id,
                self.ec2_key_pair,
                self.ec2_security_groups,
                self.ec2_subnet_id,
                self.ec2_tags,
                submit_button
            ], spacing=10),
            padding=20
        )
    
    def create_vpc_form(self) -> ft.Container:
        """Create VPC provisioning form."""
        self.vpc_cidr = ft.TextField(
            label="VPC CIDR Block",
            value="10.0.0.0/16",
            hint_text="e.g., 10.0.0.0/16"
        )
        
        self.vpc_azs = ft.TextField(
            label="Availability Zones (comma-separated)",
            value="us-west-2a, us-west-2b",
            hint_text="us-west-2a, us-west-2b"
        )
        
        self.vpc_public_subnets = ft.TextField(
            label="Public Subnet CIDRs (comma-separated)",
            value="10.0.1.0/24, 10.0.2.0/24",
            hint_text="10.0.1.0/24, 10.0.2.0/24"
        )
        
        self.vpc_private_subnets = ft.TextField(
            label="Private Subnet CIDRs (comma-separated)",
            value="10.0.10.0/24, 10.0.20.0/24",
            hint_text="10.0.10.0/24, 10.0.20.0/24"
        )
        
        self.vpc_enable_dns = ft.Checkbox(
            label="Enable DNS support and hostnames",
            value=True
        )
        
        submit_button = ft.ElevatedButton(
            text="Submit VPC Request",
            on_click=self.submit_vpc_request,
            style=ft.ButtonStyle(
                bgcolor=ft.colors.GREEN,
                color=ft.colors.WHITE
            )
        )
        
        return ft.Container(
            content=ft.Column([
                self.vpc_cidr,
                self.vpc_azs,
                self.vpc_public_subnets,
                self.vpc_private_subnets,
                self.vpc_enable_dns,
                submit_button
            ], spacing=10),
            padding=20
        )
    
    def create_s3_form(self) -> ft.Container:
        """Create S3 provisioning form."""
        self.s3_bucket_name = ft.TextField(
            label="Bucket Name",
            hint_text="my-unique-bucket-name-12345"
        )
        
        self.s3_versioning = ft.Checkbox(
            label="Enable versioning",
            value=False
        )
        
        self.s3_encryption = ft.Checkbox(
            label="Enable encryption",
            value=True
        )
        
        self.s3_public_read = ft.Checkbox(
            label="Allow public read access",
            value=False
        )
        
        submit_button = ft.ElevatedButton(
            text="Submit S3 Request",
            on_click=self.submit_s3_request,
            style=ft.ButtonStyle(
                bgcolor=ft.colors.ORANGE,
                color=ft.colors.WHITE
            )
        )
        
        return ft.Container(
            content=ft.Column([
                self.s3_bucket_name,
                self.s3_versioning,
                self.s3_encryption,
                self.s3_public_read,
                submit_button
            ], spacing=10),
            padding=20
        )
    
    def create_status_form(self) -> ft.Container:
        """Create request status checking form."""
        self.status_request_id = ft.TextField(
            label="Request ID",
            hint_text="Enter request ID to check status"
        )
        
        check_button = ft.ElevatedButton(
            text="Check Status",
            on_click=self.check_request_status,
            style=ft.ButtonStyle(
                bgcolor=ft.colors.PURPLE,
                color=ft.colors.WHITE
            )
        )
        
        self.status_display = ft.Text("")
        
        return ft.Container(
            content=ft.Column([
                self.status_request_id,
                check_button,
                ft.Divider(),
                self.status_display
            ], spacing=10),
            padding=20
        )
    
    def submit_ec2_request(self, e):
        """Submit EC2 provisioning request."""
        try:
            # Parse security groups
            security_groups = []
            if self.ec2_security_groups.value:
                security_groups = [sg.strip() for sg in self.ec2_security_groups.value.split(',')]
            
            # Parse tags
            tags = {}
            if self.ec2_tags.value:
                tags = json.loads(self.ec2_tags.value)
            
            # Prepare request data
            request_data = {
                "instance_type": self.ec2_instance_type.value,
                "ami_id": self.ec2_ami_id.value,
                "key_pair_name": self.ec2_key_pair.value,
                "security_group_ids": security_groups,
                "tags": tags
            }
            
            if self.ec2_subnet_id.value:
                request_data["subnet_id"] = self.ec2_subnet_id.value
            
            # Submit request
            response = requests.post(
                f"{self.api_base_url}/requests/ec2",
                json=request_data,
                params={"requester": "ui-user"}
            )
            
            if response.status_code == 200:
                result = response.json()
                self.current_request_id = result["request_id"]
                self.status_text.value = f"✅ {result['message']} (ID: {result['request_id']})"
            else:
                self.status_text.value = f"❌ Error: {response.text}"
            
        except Exception as ex:
            self.status_text.value = f"❌ Error: {str(ex)}"
        
        self.page.update()
    
    def submit_vpc_request(self, e):
        """Submit VPC provisioning request."""
        try:
            # Parse comma-separated values
            azs = [az.strip() for az in self.vpc_azs.value.split(',')]
            public_cidrs = [cidr.strip() for cidr in self.vpc_public_subnets.value.split(',')]
            private_cidrs = [cidr.strip() for cidr in self.vpc_private_subnets.value.split(',')]
            
            request_data = {
                "cidr_block": self.vpc_cidr.value,
                "enable_dns_hostnames": self.vpc_enable_dns.value,
                "enable_dns_support": self.vpc_enable_dns.value,
                "availability_zones": azs,
                "public_subnet_cidrs": public_cidrs,
                "private_subnet_cidrs": private_cidrs,
                "tags": {"Environment": "dev"}
            }
            
            response = requests.post(
                f"{self.api_base_url}/requests/vpc",
                json=request_data,
                params={"requester": "ui-user"}
            )
            
            if response.status_code == 200:
                result = response.json()
                self.current_request_id = result["request_id"]
                self.status_text.value = f"✅ {result['message']} (ID: {result['request_id']})"
            else:
                self.status_text.value = f"❌ Error: {response.text}"
                
        except Exception as ex:
            self.status_text.value = f"❌ Error: {str(ex)}"
        
        self.page.update()
    
    def submit_s3_request(self, e):
        """Submit S3 provisioning request."""
        try:
            request_data = {
                "bucket_name": self.s3_bucket_name.value,
                "versioning_enabled": self.s3_versioning.value,
                "encryption_enabled": self.s3_encryption.value,
                "public_read_access": self.s3_public_read.value,
                "tags": {"Environment": "dev"}
            }
            
            response = requests.post(
                f"{self.api_base_url}/requests/s3",
                json=request_data,
                params={"requester": "ui-user"}
            )
            
            if response.status_code == 200:
                result = response.json()
                self.current_request_id = result["request_id"]
                self.status_text.value = f"✅ {result['message']} (ID: {result['request_id']})"
            else:
                self.status_text.value = f"❌ Error: {response.text}"
                
        except Exception as ex:
            self.status_text.value = f"❌ Error: {str(ex)}"
        
        self.page.update()
    
    def check_request_status(self, e):
        """Check the status of a provisioning request."""
        try:
            request_id = self.status_request_id.value
            if not request_id:
                self.status_display.value = "Please enter a request ID"
                self.page.update()
                return
            
            response = requests.get(f"{self.api_base_url}/requests/{request_id}")
            
            if response.status_code == 200:
                request_data = response.json()
                
                status_info = f"""
Request ID: {request_data['id']}
Requester: {request_data['requester']}
Resource Type: {request_data['resource_type']}
Status: {request_data['status']}
Created: {request_data['created_at']}
Updated: {request_data.get('updated_at', 'N/A')}
"""
                
                if request_data.get('error_message'):
                    status_info += f"\nError: {request_data['error_message']}"
                
                if request_data.get('terraform_output'):
                    status_info += f"\nTerraform Output: {json.dumps(request_data['terraform_output'], indent=2)}"
                
                self.status_display.value = status_info
            else:
                self.status_display.value = f"Error: {response.text}"
                
        except Exception as ex:
            self.status_display.value = f"Error: {str(ex)}"
        
        self.page.update()


def main(page: ft.Page):
    """Main entry point for the Flet app."""
    ProvisioningUI(page)


if __name__ == "__main__":
    ft.app(target=main, port=8080, view=ft.WEB_BROWSER)
