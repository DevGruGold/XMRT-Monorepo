# XMRT Ecosystem Architecture

## Overview

The XMRT ecosystem is designed as a comprehensive decentralized autonomous organization (DAO) focused on mobile Monero mining and mesh networking.

## Core Components

### 1. Mobile Miner (`core/mobile-miner/`)

The mobile mining component enables smartphones to participate in Monero mining while maintaining device safety through advanced thermal management.

**Key Features:**
- Thermal throttling to prevent overheating
- Offline mining capability with sync mechanisms
- Participation scoring system
- Battery-aware mining intensity

### 2. Mesh Network (`core/meshnet/`)

A peer-to-peer mesh networking protocol that enables devices to communicate without traditional internet infrastructure.

**Key Features:**
- Dynamic cluster formation
- Battery-aware leadership election
- Transaction compression
- Decentralized routing

### 3. XMRT Token (`core/xmrt-token/`)

The governance token for the XMRT DAO with a fixed supply of 18.4 million tokens.

**Key Features:**
- Fixed supply matching XMR economics
- Ecosystem fund allocation
- Governance voting rights
- Revenue sharing mechanisms

## DAO Components

### 1. Eliza AI (`dao/eliza/`)

An AI-powered governance agent that processes proposals and facilitates autonomous decision-making.

### 2. Treasury Management (`dao/treasury/`)

Smart contracts managing the DAO treasury and revenue distribution.

## Interfaces

### 1. Mobile Application (`interfaces/mobilemonero/`)

React-based mobile interface for mining and mesh network participation.

### 2. Dashboard (`interfaces/dashboard/`)

Flask-based administrative dashboard for system operators.

## Integration Points

The ecosystem components integrate through:
- Smart contract interactions
- REST API endpoints
- WebSocket connections for real-time data
- Mesh network protocols

## Deployment Strategy

- **Development**: Local testing with mock data
- **Staging**: Testnet deployment with limited features
- **Production**: Mainnet deployment with full feature set
