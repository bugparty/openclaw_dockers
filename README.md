# OpenClaw Docker One-Click Install

## Introduction

This is a simple OpenClaw Docker containerization setup. Deploy and start the full environment with just a few commands.

## Quick Start

```bash
# 1. Initialize environment
./setup_env.sh 

# 2. Start containers
docker compose up -d

# 3. Configure OpenClaw
docker compose exec openclaw openclaw onboard
docker compose restart openclaw
```

## Browser Configuration

Add this configuration to your OpenClaw config file (`/home/node/.openclaw/openclaw.json`) to connect to the local browser service.

```json
{
  "browser": {
    "enabled": true,
    "defaultProfile": "local-browser",
    "remoteCdpTimeoutMs": 2000,
    "remoteCdpHandshakeTimeoutMs": 4000,
    "profiles": {
      "local-browser": {
        "cdpUrl": "http://browser:9223",
        "color": "#00AA00"
      }
    }
  }
}
```

## Enter the OpenClaw CLI/TUI

```bash
docker compose exec openclaw bash
```

## Key Features

- One-click deployment: the Docker setup is already prepared
- Ready to use: no manual configuration is needed
- Developer-friendly: built-in bash access for quick container entry

## What's Included

- Complete OpenClaw environment
- Integrated Chrome browser
- Automated configuration scripts
- Docker Compose orchestration

That's it. Whether you are a beginner or an expert, you can quickly set up your OpenClaw development environment.
