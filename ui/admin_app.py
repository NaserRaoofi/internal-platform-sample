"""
Admin UI Application for Internal Developer Platform.

This provides a web-based interface for administrators and SREs to review,
approve, and process AWS resource provisioning requests.
"""

import json
import requests
import subprocess
import flet as ft
from typing import Dict, Any, Optional, List
from datetime import datetime


class AdminUI:
    """Main Admin UI class for the provisioning platform."""
    
    def __init__(self, page: ft.Page):
        self.page = page
        self.page.title = "IDP Admin Console"
        self.page.theme_mode = ft.ThemeMode.LIGHT
        self.page.padding = 20
        self.page.scroll = ft.ScrollMode.AUTO
        
        # API configuration
        self.api_base_url = "http://localhost:8000"
        
        # UI state
        self.pending_requests: List[Dict] = []
        self.processing_requests: List[Dict] = []
        self.completed_requests: List[Dict] = []
        
        # UI components
        self.pending_list = ft.Column()
        self.processing_list = ft.Column()
        self.completed_list = ft.Column()
        self.status_text = ft.Text("")
        
        self.setup_ui()
        self.load_requests()
    
    def setup_ui(self):
        """Set up the main UI layout."""
        # Header
        header = ft.Container(
            content=ft.Column([
                ft.Row([
                    ft.Icon(ft.icons.ADMIN_PANEL_SETTINGS, size=40, color=ft.colors.BLUE),
                    ft.Column([
                        ft.Text("IDP Admin Console", size=28, weight=ft.FontWeight.BOLD),
                        ft.Text("Infrastructure Provisioning Management", size=14, color=ft.colors.GREY_700),
                    ], spacing=0)
                ], alignment=ft.MainAxisAlignment.START, vertical_alignment=ft.CrossAxisAlignment.CENTER),
                ft.Divider(),
                ft.Row([
                    ft.ElevatedButton(
                        "🔄 Refresh",
                        on_click=self.refresh_requests,
                        icon=ft.icons.REFRESH
                    ),
                    ft.ElevatedButton(
                        "▶️ Process Approved",
                        on_click=self.process_approved_requests,
                        icon=ft.icons.PLAY_ARROW,
                        bgcolor=ft.colors.GREEN,
                        color=ft.colors.WHITE
                    ),
                    ft.ElevatedButton(
                        "📊 View API Docs",
                        on_click=lambda _: self.page.launch_url("http://localhost:8000/docs"),
                        icon=ft.icons.API
                    ),
                ], spacing=10)
            ]),
            margin=ft.margin.only(bottom=20)
        )
        
        # Tabs for different request states
        tabs = ft.Tabs(
            selected_index=0,
            animation_duration=300,
            tabs=[
                ft.Tab(
                    text="📋 Pending Approval",
                    content=ft.Container(
                        content=ft.Column([
                            ft.Text("Requests awaiting approval:", size=16, weight=ft.FontWeight.BOLD),
                            self.pending_list
                        ]),
                        padding=20
                    )
                ),
                ft.Tab(
                    text="⚙️ Processing", 
                    content=ft.Container(
                        content=ft.Column([
                            ft.Text("Requests being processed:", size=16, weight=ft.FontWeight.BOLD),
                            self.processing_list
                        ]),
                        padding=20
                    )
                ),
                ft.Tab(
                    text="✅ Completed",
                    content=ft.Container(
                        content=ft.Column([
                            ft.Text("Completed requests:", size=16, weight=ft.FontWeight.BOLD),
                            self.completed_list
                        ]),
                        padding=20
                    )
                ),
                ft.Tab(
                    text="🛠️ System Tools",
                    content=self.create_system_tools()
                )
            ]
        )
        
        # Status bar
        status_bar = ft.Container(
            content=ft.Row([
                ft.Icon(ft.icons.INFO, size=16),
                self.status_text
            ]),
            bgcolor=ft.colors.BLUE_50,
            padding=10,
            border_radius=5
        )
        
        # Main layout
        self.page.add(
            header,
            tabs,
            status_bar
        )
    
    def create_system_tools(self) -> ft.Container:
        """Create system tools tab content."""
        return ft.Container(
            content=ft.Column([
                ft.Text("System Administration Tools", size=18, weight=ft.FontWeight.BOLD),
                ft.Divider(),
                
                ft.Card(
                    content=ft.Container(
                        content=ft.Column([
                            ft.Text("🔧 Terraform Operations", size=16, weight=ft.FontWeight.BOLD),
                            ft.Text("Manage infrastructure state and operations"),
                            ft.Row([
                                ft.ElevatedButton(
                                    "Plan Changes",
                                    on_click=self.terraform_plan,
                                    icon=ft.icons.VISIBILITY
                                ),
                                ft.ElevatedButton(
                                    "Show State",
                                    on_click=self.terraform_state,
                                    icon=ft.icons.LIST
                                ),
                                ft.ElevatedButton(
                                    "Destroy All",
                                    on_click=self.terraform_destroy,
                                    icon=ft.icons.DELETE_FOREVER,
                                    bgcolor=ft.colors.RED,
                                    color=ft.colors.WHITE
                                ),
                            ], spacing=10)
                        ]),
                        padding=15
                    )
                ),
                
                ft.Card(
                    content=ft.Container(
                        content=ft.Column([
                            ft.Text("📊 Queue Management", size=16, weight=ft.FontWeight.BOLD),
                            ft.Text("Manage request queues and processing"),
                            ft.Row([
                                ft.ElevatedButton(
                                    "Clear Failed",
                                    on_click=self.clear_failed_requests,
                                    icon=ft.icons.CLEAR
                                ),
                                ft.ElevatedButton(
                                    "Retry Failed",
                                    on_click=self.retry_failed_requests,
                                    icon=ft.icons.REPLAY
                                ),
                                ft.ElevatedButton(
                                    "Export Logs",
                                    on_click=self.export_logs,
                                    icon=ft.icons.DOWNLOAD
                                ),
                            ], spacing=10)
                        ]),
                        padding=15
                    )
                ),
                
                ft.Card(
                    content=ft.Container(
                        content=ft.Column([
                            ft.Text("⚙️ System Status", size=16, weight=ft.FontWeight.BOLD),
                            ft.Text("Monitor system health and connectivity"),
                            ft.Row([
                                ft.ElevatedButton(
                                    "Test API",
                                    on_click=self.test_api_connection,
                                    icon=ft.icons.NETWORK_CHECK
                                ),
                                ft.ElevatedButton(
                                    "Check AWS",
                                    on_click=self.check_aws_connection,
                                    icon=ft.icons.CLOUD
                                ),
                                ft.ElevatedButton(
                                    "View Logs",
                                    on_click=self.view_system_logs,
                                    icon=ft.icons.ARTICLE
                                ),
                            ], spacing=10)
                        ]),
                        padding=15
                    )
                )
            ], spacing=15),
            padding=20
        )
    
    def create_request_card(self, request: Dict, show_actions: bool = True) -> ft.Card:
        """Create a card for displaying a request."""
        request_id = request.get('id', 'unknown')
        resource_type = request.get('resource_type', 'unknown')
        requester = request.get('requester', 'unknown')
        status = request.get('status', 'unknown')
        created_at = request.get('created_at', 'unknown')
        
        # Resource-specific details
        config = request.get('resource_config', {})
        details = []
        
        if resource_type == 's3':
            details = [
                f"Bucket: {config.get('bucket_name', 'unknown')}",
                f"Encryption: {'✅' if config.get('encryption_enabled') else '❌'}",
                f"Public Access: {'⚠️' if config.get('public_read_access') else '🔒'}",
                f"Versioning: {'✅' if config.get('versioning_enabled') else '❌'}"
            ]
        elif resource_type == 'ec2':
            details = [
                f"Instance Type: {config.get('instance_type', 'unknown')}",
                f"AMI ID: {config.get('ami_id', 'unknown')}",
                f"Key Pair: {config.get('key_pair_name', 'unknown')}"
            ]
        elif resource_type == 'vpc':
            details = [
                f"CIDR Block: {config.get('cidr_block', 'unknown')}",
                f"AZs: {len(config.get('availability_zones', []))}",
                f"Public Subnets: {len(config.get('public_subnet_cidrs', []))}"
            ]
        
        # Status color
        status_colors = {
            'pending': ft.colors.ORANGE,
            'in_progress': ft.colors.BLUE,
            'completed': ft.colors.GREEN,
            'failed': ft.colors.RED
        }
        status_color = status_colors.get(status, ft.colors.GREY)
        
        # Action buttons
        action_buttons = []
        if show_actions and status == 'pending':
            action_buttons = [
                ft.ElevatedButton(
                    "✅ Approve",
                    on_click=lambda _, req_id=request_id: self.approve_request(req_id),
                    bgcolor=ft.colors.GREEN,
                    color=ft.colors.WHITE,
                    icon=ft.icons.CHECK
                ),
                ft.ElevatedButton(
                    "❌ Reject",
                    on_click=lambda _, req_id=request_id: self.reject_request(req_id),
                    bgcolor=ft.colors.RED,
                    color=ft.colors.WHITE,
                    icon=ft.icons.CLOSE
                )
            ]
        
        return ft.Card(
            content=ft.Container(
                content=ft.Column([
                    ft.Row([
                        ft.Icon(
                            ft.icons.STORAGE if resource_type == 's3' 
                            else ft.icons.COMPUTER if resource_type == 'ec2'
                            else ft.icons.NETWORK_WIFI if resource_type == 'vpc'
                            else ft.icons.HELP,
                            size=24
                        ),
                        ft.Column([
                            ft.Text(f"{resource_type.upper()} Request", weight=ft.FontWeight.BOLD),
                            ft.Text(f"ID: {request_id[:8]}...", size=12, color=ft.colors.GREY_600)
                        ], spacing=0),
                        ft.Container(
                            content=ft.Text(status.upper(), color=ft.colors.WHITE, size=12),
                            bgcolor=status_color,
                            padding=ft.padding.symmetric(horizontal=8, vertical=4),
                            border_radius=12
                        )
                    ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                    
                    ft.Divider(),
                    
                    ft.Column([
                        ft.Text(f"👤 Requester: {requester}"),
                        ft.Text(f"📅 Created: {created_at[:19] if created_at != 'unknown' else 'unknown'}"),
                        *[ft.Text(f"  • {detail}") for detail in details]
                    ], spacing=5),
                    
                    *([ft.Divider(), ft.Row(action_buttons, spacing=10)] if action_buttons else [])
                ], spacing=10),
                padding=15
            ),
            margin=ft.margin.only(bottom=10)
        )
    
    def load_requests(self):
        """Load all requests from the API."""
        try:
            response = requests.get(f"{self.api_base_url}/requests", timeout=10)
            if response.status_code == 200:
                all_requests = response.json()
                
                # Categorize requests by status
                self.pending_requests = [r for r in all_requests if r.get('status') == 'pending']
                self.processing_requests = [r for r in all_requests if r.get('status') == 'in_progress']
                self.completed_requests = [r for r in all_requests if r.get('status') in ['completed', 'failed']]
                
                self.update_request_lists()
                self.status_text.value = f"Loaded {len(all_requests)} requests"
            else:
                self.status_text.value = f"Failed to load requests: {response.status_code}"
        except Exception as e:
            self.status_text.value = f"Error loading requests: {str(e)}"
        
        self.page.update()
    
    def update_request_lists(self):
        """Update the request list displays."""
        # Pending requests
        self.pending_list.controls.clear()
        if self.pending_requests:
            for request in self.pending_requests:
                self.pending_list.controls.append(self.create_request_card(request, True))
        else:
            self.pending_list.controls.append(
                ft.Text("No pending requests", style=ft.TextThemeStyle.BODY_LARGE, color=ft.colors.GREY_600)
            )
        
        # Processing requests
        self.processing_list.controls.clear()
        if self.processing_requests:
            for request in self.processing_requests:
                self.processing_list.controls.append(self.create_request_card(request, False))
        else:
            self.processing_list.controls.append(
                ft.Text("No requests being processed", style=ft.TextThemeStyle.BODY_LARGE, color=ft.colors.GREY_600)
            )
        
        # Completed requests
        self.completed_list.controls.clear()
        if self.completed_requests:
            for request in self.completed_requests[-10:]:  # Show last 10
                self.completed_list.controls.append(self.create_request_card(request, False))
        else:
            self.completed_list.controls.append(
                ft.Text("No completed requests", style=ft.TextThemeStyle.BODY_LARGE, color=ft.colors.GREY_600)
            )
    
    def refresh_requests(self, e):
        """Refresh the request lists."""
        self.status_text.value = "Refreshing..."
        self.page.update()
        self.load_requests()
    
    def approve_request(self, request_id: str):
        """Approve a specific request."""
        try:
            # Update the request status via API instead of using the script
            response = requests.patch(
                f"{self.api_base_url}/requests/{request_id}/status",
                json={"status": "in_progress"},
                timeout=10
            )
            
            if response.status_code == 200:
                self.status_text.value = f"✅ Request {request_id[:8]}... approved and processing started"
                
                # Now trigger the actual terraform processing
                self.process_single_request(request_id)
                
                self.load_requests()  # Refresh the lists
            else:
                self.status_text.value = f"❌ Failed to approve request: HTTP {response.status_code}"
        except Exception as e:
            self.status_text.value = f"❌ Error approving request: {str(e)}"
        
        self.page.update()
    
    def process_single_request(self, request_id: str):
        """Process a single approved request using Terraform."""
        try:
            # Get the request details from API
            response = requests.get(f"{self.api_base_url}/requests/{request_id}", timeout=10)
            if response.status_code != 200:
                raise Exception(f"Failed to fetch request details: {response.status_code}")
            
            request_data = response.json()
            
            # Load existing terraform variables file or create new one
            import os
            terraform_dir = "/home/sirwan/mini_IPCs/terraform/environments/dev"
            tfvars_file = os.path.join(terraform_dir, "terraform.tfvars.json")
            
            # Load existing variables
            try:
                with open(tfvars_file, 'r') as f:
                    terraform_vars = json.load(f)
            except (FileNotFoundError, json.JSONDecodeError):
                terraform_vars = {"instance_requests": {}}
            
            # Add the new request to existing ones (only if not already there)
            if request_id not in terraform_vars.get("instance_requests", {}):
                terraform_vars.setdefault("instance_requests", {})[request_id] = {
                    "resource_type": request_data["resource_type"],
                    "resource_config": request_data["resource_config"],
                    "requester": request_data["requester"]
                }
                
                # Write the updated terraform variables file
                with open(tfvars_file, 'w') as f:
                    json.dump(terraform_vars, f, indent=2)
            
            # Run terraform apply
            result = subprocess.run([
                "bash", "-c", 
                f"cd {terraform_dir} && terraform apply -var-file=terraform.tfvars.json -auto-approve"
            ], capture_output=True, text=True, timeout=300)
            
            if result.returncode == 0:
                # Update status to completed
                requests.patch(
                    f"{self.api_base_url}/requests/{request_id}/status",
                    json={"status": "completed"},
                    timeout=10
                )
                self.status_text.value = f"✅ Request {request_id[:8]}... completed successfully!"
                
                # Clean up old completed requests from terraform vars to keep file manageable
                self.cleanup_terraform_vars()
                
            else:
                # Update status to failed
                requests.patch(
                    f"{self.api_base_url}/requests/{request_id}/status",
                    json={
                        "status": "failed", 
                        "error_message": f"Terraform failed: {result.stderr[:200]}"
                    },
                    timeout=10
                )
                self.status_text.value = f"❌ Request {request_id[:8]}... failed: {result.stderr[:100]}"
                
        except Exception as e:
            # Update status to failed
            try:
                requests.patch(
                    f"{self.api_base_url}/requests/{request_id}/status",
                    json={
                        "status": "failed", 
                        "error_message": f"Processing error: {str(e)}"
                    },
                    timeout=10
                )
            except:
                pass
            
            self.status_text.value = f"❌ Error processing request: {str(e)}"
    
    def cleanup_terraform_vars(self):
        """Remove completed/failed requests from terraform vars to keep file manageable."""
        try:
            # Get all requests from API to know which ones are completed/failed
            response = requests.get(f"{self.api_base_url}/requests", timeout=10)
            if response.status_code != 200:
                return
            
            all_requests = response.json()
            active_request_ids = {
                req['id'] for req in all_requests 
                if req.get('status') in ['pending', 'in_progress']
            }
            
            # Load current terraform vars
            import os
            terraform_dir = "/home/sirwan/mini_IPCs/terraform/environments/dev"
            tfvars_file = os.path.join(terraform_dir, "terraform.tfvars.json")
            
            try:
                with open(tfvars_file, 'r') as f:
                    terraform_vars = json.load(f)
                
                # Keep only active requests
                original_count = len(terraform_vars.get("instance_requests", {}))
                terraform_vars["instance_requests"] = {
                    req_id: req_data 
                    for req_id, req_data in terraform_vars.get("instance_requests", {}).items()
                    if req_id in active_request_ids
                }
                
                # Write back if we removed anything
                new_count = len(terraform_vars["instance_requests"])
                if new_count < original_count:
                    with open(tfvars_file, 'w') as f:
                        json.dump(terraform_vars, f, indent=2)
                    print(f"Cleaned up {original_count - new_count} completed requests from terraform vars")
                        
            except (FileNotFoundError, json.JSONDecodeError):
                pass  # File doesn't exist or is invalid, ignore
                
        except Exception as e:
            print(f"Error cleaning up terraform vars: {e}")
    
    def reject_request(self, request_id: str):
        """Reject a specific request."""
        def close_dialog(e):
            dialog.open = False
            self.page.update()
        
        def confirm_reject(e):
            reason = reason_field.value or "No reason provided"
            dialog.open = False
            self.page.update()
            
            try:
                result = subprocess.run([
                    "./scripts/approval-workflow.sh", "reject", request_id, "admin-ui", reason
                ], capture_output=True, text=True, cwd="/home/sirwan/mini_IPCs")
                
                if result.returncode == 0:
                    self.status_text.value = f"❌ Request {request_id[:8]}... rejected"
                    self.load_requests()
                else:
                    self.status_text.value = f"❌ Failed to reject request: {result.stderr}"
            except Exception as e:
                self.status_text.value = f"❌ Error rejecting request: {str(e)}"
            
            self.page.update()
        
        reason_field = ft.TextField(
            label="Rejection reason",
            multiline=True,
            expand=True
        )
        
        dialog = ft.AlertDialog(
            modal=True,
            title=ft.Text("Reject Request"),
            content=ft.Container(
                content=ft.Column([
                    ft.Text(f"Are you sure you want to reject request {request_id[:8]}...?"),
                    reason_field
                ], spacing=10),
                width=400,
                height=150
            ),
            actions=[
                ft.TextButton("Cancel", on_click=close_dialog),
                ft.ElevatedButton("Reject", on_click=confirm_reject, bgcolor=ft.colors.RED, color=ft.colors.WHITE)
            ]
        )
        
        self.page.dialog = dialog
        dialog.open = True
        self.page.update()
    
    def process_approved_requests(self, e):
        """Process all approved requests."""
        self.status_text.value = "⚙️ Processing approved requests..."
        self.page.update()
        
        try:
            result = subprocess.run([
                "./scripts/approval-workflow.sh", "process"
            ], capture_output=True, text=True, cwd="/home/sirwan/mini_IPCs")
            
            if result.returncode == 0:
                self.status_text.value = "✅ Approved requests processed successfully"
                self.load_requests()
            else:
                self.status_text.value = f"❌ Processing failed: {result.stderr}"
        except Exception as e:
            self.status_text.value = f"❌ Error processing requests: {str(e)}"
        
        self.page.update()
    
    # System tools methods
    def terraform_plan(self, e):
        """Run terraform plan."""
        self.run_terraform_command("plan", "📋 Terraform plan completed")
    
    def terraform_state(self, e):
        """Show terraform state."""
        self.run_terraform_command("state list", "📊 Terraform state retrieved")
    
    def terraform_destroy(self, e):
        """Destroy all terraform resources."""
        def confirm_destroy(e):
            dialog.open = False
            self.page.update()
            self.run_terraform_command("destroy -auto-approve", "💥 All resources destroyed")
        
        def cancel_destroy(e):
            dialog.open = False
            self.page.update()
        
        dialog = ft.AlertDialog(
            modal=True,
            title=ft.Text("⚠️ Destroy All Resources"),
            content=ft.Text("This will PERMANENTLY DELETE all managed infrastructure. Are you sure?"),
            actions=[
                ft.TextButton("Cancel", on_click=cancel_destroy),
                ft.ElevatedButton("DESTROY", on_click=confirm_destroy, bgcolor=ft.colors.RED, color=ft.colors.WHITE)
            ]
        )
        
        self.page.dialog = dialog
        dialog.open = True
        self.page.update()
    
    def run_terraform_command(self, command: str, success_message: str):
        """Run a terraform command."""
        try:
            result = subprocess.run([
                "bash", "-c", f"cd terraform/environments/dev && terraform {command}"
            ], capture_output=True, text=True, cwd="/home/sirwan/mini_IPCs")
            
            if result.returncode == 0:
                self.status_text.value = success_message
            else:
                self.status_text.value = f"❌ Command failed: {result.stderr[:100]}..."
        except Exception as e:
            self.status_text.value = f"❌ Error running command: {str(e)}"
        
        self.page.update()
    
    def clear_failed_requests(self, e):
        """Clear failed requests from queue."""
        self.status_text.value = "🧹 Clearing failed requests..."
        self.page.update()
    
    def retry_failed_requests(self, e):
        """Retry failed requests."""
        self.status_text.value = "🔄 Retrying failed requests..."
        self.page.update()
    
    def export_logs(self, e):
        """Export system logs."""
        self.status_text.value = "📁 Exporting logs..."
        self.page.update()
    
    def test_api_connection(self, e):
        """Test API connection."""
        try:
            response = requests.get(f"{self.api_base_url}/", timeout=5)
            if response.status_code == 200:
                self.status_text.value = "✅ API connection successful"
            else:
                self.status_text.value = f"⚠️ API returned status {response.status_code}"
        except Exception as e:
            self.status_text.value = f"❌ API connection failed: {str(e)}"
        
        self.page.update()
    
    def check_aws_connection(self, e):
        """Check AWS connection."""
        try:
            result = subprocess.run(["aws", "sts", "get-caller-identity"], 
                                  capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                self.status_text.value = "✅ AWS connection successful"
            else:
                self.status_text.value = "❌ AWS connection failed"
        except Exception as e:
            self.status_text.value = f"❌ AWS check failed: {str(e)}"
        
        self.page.update()
    
    def view_system_logs(self, e):
        """View system logs."""
        self.status_text.value = "📄 Opening system logs..."
        self.page.update()


def main(page: ft.Page):
    """Main function to create the admin UI."""
    AdminUI(page)


if __name__ == "__main__":
    ft.app(target=main, port=8081, view=ft.AppView.WEB_BROWSER)
