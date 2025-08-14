#!/usr/bin/env python3
"""
XMRT Dashboard - Administrative Interface
Flask application for monitoring and managing the XMRT ecosystem
"""

import os
import json
import logging
from datetime import datetime, timedelta
from flask import Flask, render_template, jsonify, request, redirect, url_for
from flask_cors import CORS
import redis
import requests
from typing import Dict, List, Any

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')

# Enable CORS for all routes
CORS(app, origins=['*'])

# Redis connection for caching and real-time data
try:
    redis_client = redis.Redis(
        host=os.environ.get('REDIS_HOST', 'localhost'),
        port=int(os.environ.get('REDIS_PORT', 6379)),
        db=0,
        decode_responses=True
    )
    redis_client.ping()
    logger.info("Redis connection established")
except Exception as e:
    logger.warning(f"Redis connection failed: {e}")
    redis_client = None

# Configuration
CONFIG = {
    'BLOCKCHAIN_RPC_URL': os.environ.get('BLOCKCHAIN_RPC_URL', 'http://localhost:8545'),
    'AGENT_API_URL': os.environ.get('AGENT_API_URL', 'http://localhost:5001'),
    'MESH_API_URL': os.environ.get('MESH_API_URL', 'http://localhost:5002'),
    'TREASURY_CONTRACT': os.environ.get('TREASURY_CONTRACT', '0x...'),
    'XMRT_TOKEN_CONTRACT': os.environ.get('XMRT_TOKEN_CONTRACT', '0x...')
}

@app.route('/')
def dashboard():
    """Main dashboard view"""
    try:
        # Get system status
        system_status = get_system_status()
        
        # Get agent information
        agents = get_active_agents()
        
        # Get treasury data
        treasury_data = get_treasury_data()
        
        # Get recent activities
        recent_activities = get_recent_activities()
        
        return render_template('dashboard.html',
                             system_status=system_status,
                             agents=agents,
                             treasury_data=treasury_data,
                             recent_activities=recent_activities)
    except Exception as e:
        logger.error(f"Dashboard error: {e}")
        return render_template('error.html', error=str(e)), 500

@app.route('/api/system/status')
def api_system_status():
    """API endpoint for system status"""
    try:
        status = get_system_status()
        return jsonify(status)
    except Exception as e:
        logger.error(f"System status API error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/agents')
def api_agents():
    """API endpoint for agent information"""
    try:
        agents = get_active_agents()
        return jsonify(agents)
    except Exception as e:
        logger.error(f"Agents API error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/agents', methods=['POST'])
def api_create_agent():
    """API endpoint to create new agent"""
    try:
        agent_config = request.get_json()
        
        # Validate required fields
        required_fields = ['name', 'type', 'config']
        for field in required_fields:
            if field not in agent_config:
                return jsonify({'error': f'Missing required field: {field}'}), 400
        
        # Create agent
        result = create_agent(agent_config)
        
        if result['success']:
            return jsonify(result), 201
        else:
            return jsonify(result), 400
            
    except Exception as e:
        logger.error(f"Create agent API error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/treasury')
def api_treasury():
    """API endpoint for treasury data"""
    try:
        treasury_data = get_treasury_data()
        return jsonify(treasury_data)
    except Exception as e:
        logger.error(f"Treasury API error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/workflows')
def api_workflows():
    """API endpoint for workflow information"""
    try:
        workflows = get_workflows()
        return jsonify(workflows)
    except Exception as e:
        logger.error(f"Workflows API error: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/logs')
def api_logs():
    """API endpoint for system logs"""
    try:
        limit = request.args.get('limit', 100, type=int)
        level = request.args.get('level', 'INFO')
        
        logs = get_system_logs(limit=limit, level=level)
        return jsonify(logs)
    except Exception as e:
        logger.error(f"Logs API error: {e}")
        return jsonify({'error': str(e)}), 500

def get_system_status() -> Dict[str, Any]:
    """Get current system status"""
    status = {
        'timestamp': datetime.utcnow().isoformat(),
        'api_status': 'unknown',
        'agents_status': 'unknown',
        'treasury_status': 'unknown',
        'mesh_status': 'unknown',
        'redis_status': 'connected' if redis_client else 'disconnected'
    }
    
    # Check API health
    try:
        response = requests.get(f"{CONFIG['AGENT_API_URL']}/health", timeout=5)
        status['api_status'] = 'healthy' if response.status_code == 200 else 'unhealthy'
    except:
        status['api_status'] = 'unreachable'
    
    # Check mesh network
    try:
        response = requests.get(f"{CONFIG['MESH_API_URL']}/status", timeout=5)
        status['mesh_status'] = 'healthy' if response.status_code == 200 else 'unhealthy'
    except:
        status['mesh_status'] = 'unreachable'
    
    # Check treasury (blockchain connection)
    try:
        # This would check blockchain connectivity
        status['treasury_status'] = 'healthy'  # Placeholder
    except:
        status['treasury_status'] = 'unreachable'
    
    return status

def get_active_agents() -> List[Dict[str, Any]]:
    """Get list of active agents"""
    # This would fetch from the agent orchestrator
    # For now, return mock data
    return [
        {
            'id': 'governance-agent-001',
            'name': 'Governance Agent',
            'type': 'governance',
            'status': 'active',
            'last_activity': (datetime.utcnow() - timedelta(minutes=5)).isoformat(),
            'tasks_completed': 42,
            'success_rate': 0.95
        },
        {
            'id': 'treasury-agent-001',
            'name': 'Treasury Agent',
            'type': 'treasury',
            'status': 'active',
            'last_activity': (datetime.utcnow() - timedelta(minutes=2)).isoformat(),
            'tasks_completed': 28,
            'success_rate': 0.98
        },
        {
            'id': 'mining-coordinator-001',
            'name': 'Mining Coordinator',
            'type': 'mining',
            'status': 'idle',
            'last_activity': (datetime.utcnow() - timedelta(hours=1)).isoformat(),
            'tasks_completed': 156,
            'success_rate': 0.92
        }
    ]

def get_treasury_data() -> Dict[str, Any]:
    """Get treasury information"""
    # This would fetch from blockchain
    # For now, return mock data
    return {
        'total_value_locked': 1250000.50,
        'xmrt_balance': 850000.25,
        'eth_balance': 125.75,
        'usdc_balance': 275000.00,
        'recent_transactions': [
            {
                'hash': '0x1234...5678',
                'type': 'reward_distribution',
                'amount': 5000.00,
                'timestamp': (datetime.utcnow() - timedelta(hours=2)).isoformat()
            },
            {
                'hash': '0x9876...4321',
                'type': 'fee_collection',
                'amount': 125.50,
                'timestamp': (datetime.utcnow() - timedelta(hours=6)).isoformat()
            }
        ]
    }

def get_recent_activities() -> List[Dict[str, Any]]:
    """Get recent system activities"""
    return [
        {
            'timestamp': (datetime.utcnow() - timedelta(minutes=5)).isoformat(),
            'type': 'agent_action',
            'description': 'Governance Agent processed proposal #42',
            'status': 'success'
        },
        {
            'timestamp': (datetime.utcnow() - timedelta(minutes=15)).isoformat(),
            'type': 'treasury_action',
            'description': 'Reward distribution completed',
            'status': 'success'
        },
        {
            'timestamp': (datetime.utcnow() - timedelta(hours=1)).isoformat(),
            'type': 'system_event',
            'description': 'New mining cluster formed',
            'status': 'info'
        }
    ]

def create_agent(config: Dict[str, Any]) -> Dict[str, Any]:
    """Create a new agent"""
    try:
        # This would call the agent orchestrator API
        # For now, return mock response
        agent_id = f"{config['type']}-agent-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}"
        
        return {
            'success': True,
            'agent_id': agent_id,
            'message': f"Agent '{config['name']}' created successfully"
        }
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }

def get_workflows() -> List[Dict[str, Any]]:
    """Get workflow information"""
    return [
        {
            'id': 'proposal-processing',
            'name': 'Proposal Processing Workflow',
            'status': 'active',
            'executions': 15,
            'success_rate': 0.93,
            'last_execution': (datetime.utcnow() - timedelta(hours=2)).isoformat()
        },
        {
            'id': 'reward-distribution',
            'name': 'Reward Distribution Workflow',
            'status': 'scheduled',
            'executions': 8,
            'success_rate': 1.0,
            'last_execution': (datetime.utcnow() - timedelta(days=1)).isoformat()
        }
    ]

def get_system_logs(limit: int = 100, level: str = 'INFO') -> List[Dict[str, Any]]:
    """Get system logs"""
    # This would fetch from logging system
    # For now, return mock data
    logs = []
    for i in range(min(limit, 20)):
        logs.append({
            'timestamp': (datetime.utcnow() - timedelta(minutes=i*5)).isoformat(),
            'level': level,
            'component': 'dashboard',
            'message': f'Sample log message {i+1}',
            'details': {}
        })
    
    return logs

@app.errorhandler(404)
def not_found(error):
    return render_template('error.html', error='Page not found'), 404

@app.errorhandler(500)
def internal_error(error):
    return render_template('error.html', error='Internal server error'), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('FLASK_ENV') == 'development'
    
    logger.info(f"Starting XMRT Dashboard on port {port}")
    app.run(host='0.0.0.0', port=port, debug=debug)