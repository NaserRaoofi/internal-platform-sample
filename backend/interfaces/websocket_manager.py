"""
WebSocket Connection Manager - Real-time communication interface
==============================================================

Manages WebSocket connections for real-time job status updates.
"""

import json
import logging
from typing import Dict, List, Set
from fastapi import WebSocket, WebSocketDisconnect

logger = logging.getLogger(__name__)

class ConnectionManager:
    """Manages WebSocket connections for real-time updates"""
    
    def __init__(self):
        self.active_connections: Dict[str, Set[WebSocket]] = {}
        self.connection_jobs: Dict[WebSocket, Set[str]] = {}
    
    async def connect(self, websocket: WebSocket, job_id: str = None):
        """Accept a WebSocket connection"""
        await websocket.accept()
        
        # Initialize connection tracking
        if websocket not in self.connection_jobs:
            self.connection_jobs[websocket] = set()
        
        # Subscribe to specific job if provided
        if job_id:
            await self.subscribe_to_job(websocket, job_id)
        
        logger.info(f"WebSocket connected{f' to job {job_id}' if job_id else ''}")
    
    async def disconnect(self, websocket: WebSocket):
        """Handle WebSocket disconnection"""
        # Remove from all job subscriptions
        if websocket in self.connection_jobs:
            for job_id in self.connection_jobs[websocket].copy():
                await self.unsubscribe_from_job(websocket, job_id)
            del self.connection_jobs[websocket]
        
        logger.info("WebSocket disconnected")
    
    async def subscribe_to_job(self, websocket: WebSocket, job_id: str):
        """Subscribe WebSocket to job updates"""
        if job_id not in self.active_connections:
            self.active_connections[job_id] = set()
        
        self.active_connections[job_id].add(websocket)
        
        if websocket in self.connection_jobs:
            self.connection_jobs[websocket].add(job_id)
        
        logger.debug(f"WebSocket subscribed to job {job_id}")
    
    async def unsubscribe_from_job(self, websocket: WebSocket, job_id: str):
        """Unsubscribe WebSocket from job updates"""
        if job_id in self.active_connections:
            self.active_connections[job_id].discard(websocket)
            
            # Clean up empty job subscriptions
            if not self.active_connections[job_id]:
                del self.active_connections[job_id]
        
        if websocket in self.connection_jobs:
            self.connection_jobs[websocket].discard(job_id)
        
        logger.debug(f"WebSocket unsubscribed from job {job_id}")
    
    async def send_to_job(self, job_id: str, message: dict):
        """Send message to all connections subscribed to a job"""
        if job_id not in self.active_connections:
            return
        
        disconnected = set()
        message_str = json.dumps(message)
        
        for websocket in self.active_connections[job_id].copy():
            try:
                await websocket.send_text(message_str)
            except Exception as e:
                logger.warning(f"Failed to send message to WebSocket: {str(e)}")
                disconnected.add(websocket)
        
        # Clean up disconnected WebSockets
        for websocket in disconnected:
            await self.disconnect(websocket)
    
    async def send_to_connection(self, websocket: WebSocket, message: dict):
        """Send message to specific WebSocket connection"""
        try:
            await websocket.send_text(json.dumps(message))
        except Exception as e:
            logger.warning(f"Failed to send message to specific WebSocket: {str(e)}")
            await self.disconnect(websocket)
    
    async def broadcast(self, message: dict):
        """Broadcast message to all active connections"""
        message_str = json.dumps(message)
        disconnected = set()
        
        all_connections = set()
        for connections in self.active_connections.values():
            all_connections.update(connections)
        
        for websocket in all_connections:
            try:
                await websocket.send_text(message_str)
            except Exception as e:
                logger.warning(f"Failed to broadcast to WebSocket: {str(e)}")
                disconnected.add(websocket)
        
        # Clean up disconnected WebSockets
        for websocket in disconnected:
            await self.disconnect(websocket)
    
    def get_connection_count(self) -> int:
        """Get total number of active connections"""
        all_connections = set()
        for connections in self.active_connections.values():
            all_connections.update(connections)
        return len(all_connections)
    
    def get_job_subscriber_count(self, job_id: str) -> int:
        """Get number of connections subscribed to a specific job"""
        return len(self.active_connections.get(job_id, set()))
    
    def get_stats(self) -> dict:
        """Get connection manager statistics"""
        return {
            "total_connections": self.get_connection_count(),
            "active_job_subscriptions": len(self.active_connections),
            "jobs_with_subscribers": list(self.active_connections.keys())
        }

# Global connection manager instance
manager = ConnectionManager()
