# Dittah Studio

*Build with Intelligence. Run with Confidence.*

Dittah Studio is a self-hosted platform that combines AI-powered creativity with deterministic code execution. It solves the biggest barrier to AI adoption in enterprises — unpredictability — by using AI to *build* solutions and locked-down code to *run* them.

### Chat Studio — Instant Answers from Your Documents

Upload your documents and ask questions in plain English. Chat Studio gives you instant, accurate answers from hundreds of files and shows exactly where each answer comes from. It's secure and role-based — users only access documents they're authorized to view.

1. Upload documents into organized folders
2. Ask questions in natural language
3. Get answers with source citations

### Build Studio — Natural Language to Production-Ready Workflows

Describe what you want the way you'd explain it to a colleague. AI generates the full data workflow for you. Test it, tweak it, then freeze it into deterministic code that runs the same way every time.

1. **Describe** — Tell Build Studio what you want in plain English
2. **Preview & Freeze** — Test and validate, then lock the workflow into predictable code
3. **Run Reliably** — Execute via APIs, automations, SFTP, or chat with consistent results

### Key Principles

- **AI creates, code executes** — AI handles the creative work; frozen code guarantees consistent output
- **Privacy-first** — Deploy on-premise or in the cloud; your data stays where you need it
- **No coding required** — Non-technical users can build automated workflows
- **Enterprise-grade** — Role-based access, auditability, and compliance-ready

Learn more at [dittah.com](https://dittah.com/)

---

## Prerequisites

You need **Docker** and **Docker Compose v2** installed on your machine.

### Install Docker

| Platform | Instructions |
|----------|-------------|
| **Windows** | Install [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/) |
| **macOS** | Install [Docker Desktop for Mac](https://docs.docker.com/desktop/setup/install/mac-install/) |
| **Linux** | Install [Docker Engine](https://docs.docker.com/engine/install/) |

Docker Desktop includes Docker Compose v2. On Linux, install the [Compose plugin](https://docs.docker.com/compose/install/linux/) separately if needed.

Verify your installation:

```bash
docker --version          # Docker Engine 24+
docker compose version    # Docker Compose v2+
```

### System Requirements

| Resource | Minimum |
|----------|---------|
| CPU | 4 vCPU |
| RAM | 16 GB |
| Disk | 50 GB free |

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/ai-dittah/studio.git
cd studio

# 2. Run the installer
chmod +x install.sh
./install.sh
```

The installer will:
1. Check that Docker is installed and running
2. Generate secure passwords and create a `.env` file
3. Pull Docker images from Docker Hub
4. Start all services
5. Run health checks

Once complete, open **http://localhost:4200** in your browser to start the setup wizard:
1. Select your profile (Light / Medium / Production)
2. Create your admin account
3. Start using Dittah!

## Services

| Service | Port | Description |
|---------|------|-------------|
| UI | 4200 | Web interface |
| REST API | 8080 | Backend API server |
| Orchestrator | - | Workflow execution engine (JMS) |
| Intelligence | - | Data processing and AI code generation |
| PostgreSQL | 5432 | Database (localhost only) |
| Artemis | 61616 | Message broker (localhost only) |

## Management

```bash
# Check service health
./healthcheck.sh

# Update to latest version
./update.sh

# Stop and remove all containers and data
./uninstall.sh
```

## Manual Setup

If you prefer to configure things yourself instead of using `install.sh`:

```bash
# 1. Copy the example environment file
cp .env.example .env

# 2. Edit .env and set your own passwords
#    At minimum, set POSTGRES_PASSWORD to something secure
nano .env

# 3. Pull images and start
./deploy.sh
```

## Profiles

Profiles are selected during the setup wizard after first launch.

| Profile | RAM | LLM | Use Case |
|---------|-----|-----|----------|
| **Light** | 8 GB | Local Ollama (llama3.2:3b) | Development, small datasets |
| **Medium** | 16 GB | Local Ollama (qwen2.5:7b-instruct) | Recommended for most users |
| **Production** | - | Cloud APIs (Groq) | Requires API key, best quality |

## Architecture

```
                                                          ┌─────────────────┐
                                                          │   AI Service     │
┌────────────────────────────────────────────────┐        │                  │
│                Docker Containers               │        │  Local: Ollama   │
│                                                │        │       OR         │
│  ┌─────┐   ┌─────┐   ┌───────────┐            │        │  Cloud: Groq /   │
│  │ ui  │──►│ api │──►│artemis-mq │            │        │  Anthropic /     │
│  └─────┘   └──┬──┘   └─────┬─────┘            │        │  OpenAI /        │
│               │             │                  │        │  Gemini          │
│               │       ┌─────┴──────┐           │        └──────▲───────────┘
│               │       │orchestrator│           │               │
│               │       └─────┬──────┘           │               │
│               │             │                  │               │
│               │       ┌─────┴──────┐           │               │
│               │       │intelligence├───────────┼───────────────┘
│               │       └─────┬──────┘           │
│               │             │                  │
│            ┌──┴─────────────┴──┐               │
│            │     postgres      │               │
│            │ PostgreSQL+pgvector│               │
│            └───────────────────┘               │
└────────────────────────────────────────────────┘
```

This is a personal, single-node deployment that runs entirely on Docker. For enterprise multi-node deployments, high availability, and dedicated support, contact **info@dittah.com**.

## Troubleshooting

**Services won't start?**
```bash
# Check container status
docker compose ps

# View logs for a specific service
docker compose logs -f api
docker compose logs -f postgres
```

**Port already in use?**
Edit `.env` and change the port:
```
REST_SERVER_PORT=9080
UI_PORT=9200
```

**Need to start fresh?**
```bash
./deploy.sh --fresh
```
This removes all data volumes and reinitializes the database.

## License and Terms of Use

Dittah Studio is proprietary software. We provide free access to our Docker images for **personal, non-commercial use** and **internal evaluation purposes**.

- **Personal Use:** Free (Limited to 1 Admin, 1 Concurrent Job)
- **Commercial/Enterprise Use:** Requires a commercial license. For production deployments, multi-user access, or enterprise support, contact **info@dittah.com**

By pulling and running these images, you agree to the [Dittah End-User License Agreement](LICENSE).
