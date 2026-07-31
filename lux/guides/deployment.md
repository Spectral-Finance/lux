# Production Deployment Guide

This guide covers deploying Lux-based applications to production environments, including setup, configuration, monitoring, and operational best practices.

## Prerequisites

Before deploying, ensure your environment meets these requirements:

- **Elixir**: 1.18+ with OTP 27
- **Erlang**: 27.2+
- **Python**: 3.12+ (if using Python lenses/prisms)
- **Node.js**: 22.13+ (if using Node.js lenses/prisms)
- **Database**: PostgreSQL 15+ (for persistent agent memory)
- **Redis**: 7+ (for PubSub and caching, optional)

## Build and Release

### Mix Release

The recommended deployment method is Elixir releases:

```bash
# Set production environment
export MIX_ENV=prod

# Compile the project
mix compile

# Generate release
mix release lux

# The release will be at _build/prod/rel/lux/
```

### Release Configuration

Create `config/runtime.exs` for environment-specific settings:

```elixir
import Config

# Dynamic configuration from environment variables
config :lux, :open_ai_models,
  cheapest: System.get_env("LUX_LLM_CHEAPEST", "gpt-4o-mini"),
  default: System.get_env("LUX_LLM_DEFAULT", "gpt-4o-mini"),
  smartest: System.get_env("LUX_LLM_SMARTEST", "gpt-4o")

# LLM provider credentials
config :lux, Lux.Integrations.OpenAI,
  api_key: System.get_env("OPENAI_API_KEY")

config :lux, Lux.Integrations.Anthropic,
  api_key: System.get_env("ANTHROPIC_API_KEY")

# Python bridge configuration
config :venomous, :snake_manager, %{
  snake_ttl_minutes: 5,
  perpetual_workers: 4,
  cleaner_interval: 30_000,
  python_opts: [
    module_paths: ["priv/python"],
    compressed: 9,
    packet_bytes: 4,
    python_executable: System.get_env("PYTHON_PATH", "python3")
  ]
}

# AgentHub configuration
config :lux, :agent_hub,
  pubsub_adapter: Lux.AgentHub.PubSub.Redis,
  redis_url: System.get_env("REDIS_URL")
```

### Environment Variables

Essential environment variables for production:

```bash
# Required
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-ant-..."
export SECRET_KEY_BASE="$(mix phx.gen.secret)"

# Optional but recommended
export LUX_LLM_DEFAULT="gpt-4o-mini"
export LUX_LLM_SMARTEST="gpt-4o"
export LUX_LOG_LEVEL="info"
export REDIS_URL="redis://localhost:6379/0"
export DATABASE_URL="ecto://user:pass@localhost/lux_prod"
export PYTHON_PATH="/usr/local/bin/python3"
```

## Deployment Strategies

### Option 1: Gigalixir (Recommended for Elixir)

Gigalixir provides a Heroku-like experience optimized for Elixir:

```bash
# Install Gigalixir CLI
curl -fsSL https://gigalixir.com/install.sh | bash

# Login and create app
gigalixir login
gigalixir create -n my-lux-app

# Set environment variables
gigalixir config:set OPENAI_API_KEY="sk-..."
gigalixir config:set SECRET_KEY_BASE="..."

# Deploy
git push gigalixir main
```

### Option 2: Fly.io

Fly.io offers global edge deployment:

```bash
# Install flyctl
curl -L https://fly.io/install.sh | sh

# Launch
fly launch --name my-lux-app

# Set secrets
fly secrets set OPENAI_API_KEY="sk-..."
fly secrets set SECRET_KEY_BASE="..."

# Deploy
fly deploy
```

Minimal `fly.toml`:

```toml
app = "my-lux-app"
primary_region = "ams"

[build]
  image = "hexpm/elixir:1.18.1-erlang-27.2-debian-bookworm-20250217"

[env]
  MIX_ENV = "prod"
  LUX_LOG_LEVEL = "info"

[http_service]
  internal_port = 4000
  force_https = true

[[vm]]
  memory = "1gb"
  cpu_kind = "shared"
  cpus = 1
```

### Option 3: Docker

Multi-stage Dockerfile for Lux:

```dockerfile
# Build stage
FROM hexpm/elixir:1.18.1-erlang-27.2-debian-bookworm-20250217 AS builder

RUN apt-get update && apt-get install -y \
    python3 python3-pip nodejs npm curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
COPY lux/mix.exs lux/mix.lock ./lux/
COPY lux_app/mix.exs lux_app/mix.lock ./lux_app/
RUN mix deps.get --only prod

COPY . .
RUN mix compile
RUN mix release lux

# Runtime stage
FROM debian:bookworm-20250217

RUN apt-get update && apt-get install -y \
    python3 python3-pip nodejs libssl3 libncurses6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/_build/prod/rel/lux ./
COPY priv/python/ ./priv/python/
RUN pip3 install -r priv/python/requirements.txt

ENV LUX_LOG_LEVEL=info
EXPOSE 4000

CMD ["bin/lux", "start"]
```

### Option 4: Bare Metal / VPS

For manual deployment on a VPS:

```bash
# On the server
sudo apt-get update
sudo apt-get install -y erlang elixir python3 python3-pip nodejs npm

# Clone and build
git clone https://github.com/your-org/your-lux-app.git
cd your-lux-app
export MIX_ENV=prod
mix deps.get --only prod
mix compile
mix release lux

# Run with systemd
sudo cp deploy/lux.service /etc/systemd/system/
sudo systemctl enable lux
sudo systemctl start lux
```

Example systemd unit (`deploy/lux.service`):

```ini
[Unit]
Description=Lux Agent Framework
After=network.target

[Service]
Type=simple
User=lux
WorkingDirectory=/opt/lux
Environment=MIX_ENV=prod
Environment=HOME=/opt/lux
EnvironmentFile=/etc/lux/environment
ExecStart=/opt/lux/bin/lux start
ExecStop=/opt/lux/bin/lux stop
Restart=on-failure
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

## Multi-Node Clustering

For horizontally scaled deployments, Lux supports Erlang distribution:

```elixir
# In runtime.exs
config :lux, Lux.AgentHub,
  cluster_strategy: :libcluster,
  topology: [
    strategy: Cluster.Strategy.Gossip,
    config: [
      port: 45892,
      if_addr: {0, 0, 0, 0},
      multicast_if: "eth0",
      multicast_ttl: 1
    ]
  ]
```

Nodes automatically discover each other and share the agent registry via distributed Erlang.

### Redis-Based PubSub
For environments where Erlang distribution is blocked (Kubernetes, strict firewalls), use Redis PubSub:

```elixir
config :lux, :agent_hub,
  pubsub_adapter: Lux.AgentHub.PubSub.Redis,
  redis_url: "redis://redis-cluster:6379/0"
```

This allows agents across nodes to communicate through a shared Redis instance without direct Erlang connections.

## Monitoring and Observability

### Structured Logging

Configure JSON logging for log aggregation:

```elixir
config :logger, :console,
  format: {Lux.Logging.JSONFormatter, :format},
  metadata: [:agent_id, :beam_id, :request_id, :company_id],
  level: String.to_atom(System.get_env("LUX_LOG_LEVEL", "info"))
```

### Telemetry Metrics

Lux emits Telemetry events you can hook into:

```elixir
# Attach to agent lifecycle events
:telemetry.attach("agent-metrics", [:lux, :agent, :lifecycle], fn event, measurements, metadata, _config ->
  # Send to your metrics backend (Datadog, Prometheus, etc.)
  :ok
end, nil)
```

Key events:
- `[:lux, :agent, :lifecycle]` — Agent start/stop/error
- `[:lux, :beam, :step]` — Beam step execution (timing, results)
- `[:lux, :signal, :dispatch]` — Signal routing and delivery
- `[:lux, :lens, :request]` — External API calls (latency, status codes)
- `[:lux, :llm, :completion]` — LLM API calls (token usage, latency)

### Health Checks

Expose a health endpoint for load balancers:

```elixir
# Add to your Phoenix router if using lux_app
get "/health", HealthController, :index

# HealthController
def index(conn, _params) do
  checks = %{
    agent_hub: AgentHub.healthy?(),
    llm_provider: LLMChecker.check(),
    python_bridge: PythonBridge.status(),
    memory: MemoryBackend.ping()
  }
  
  if Enum.all?(Map.values(checks)), 
    do: json(conn, %{status: "ok", checks: checks}),
    else: conn |> put_status(503) |> json(%{status: "degraded", checks: checks})
end
```

## Performance Tuning

### Python Worker Pool

Adjust Venomous settings based on workload:

```elixir
config :venomous, :snake_manager, %{
  snake_ttl_minutes: 10,        # How long idle workers survive
  perpetual_workers: 4,         # Always-available workers
  cleaner_interval: 60_000,     # Garbage collection interval (ms)
  python_opts: [
    compressed: 9,              # Compression level (0-9)
    packet_bytes: 4,            # Packet header size
  ]
}
```

Increase `perpetual_workers` for high-throughput Python workloads. Reduce `snake_ttl_minutes` if memory is constrained.

### LLM Request Optimization

- Use `gpt-4o-mini` as the default model for cost efficiency
- Reserve `gpt-4o` for complex reasoning tasks only
- Implement response caching for repeated queries
- Set appropriate `max_tokens` to control costs
- Use streaming for real-time user-facing agents

### Beam Execution Tuning

- Set per-step `timeout` values to prevent hanging workflows
- Use `parallel` blocks for independent operations
- Enable `store_io` selectively (storage overhead for large outputs)
- Configure `retries` with exponential backoff for transient failures

## Backup and Recovery

### Agent State Backup

If using persistent memory:

```bash
# Backup agent state
mix lux.backup --output backups/agent_state_$(date +%Y%m%d).tar.gz

# Restore
mix lux.restore --input backups/agent_state_20250115.tar.gz
```

### Disaster Recovery Checklist

1. Maintain infrastructure-as-code for reproducible deployments
2. Store LLM provider credentials in a secrets manager (not env files)
3. Keep Python dependencies pinned in `requirements.txt` with hashes
4. Version your company/agent definitions in git
5. Document rollback procedures for each deployment
6. Run integration tests in a staging environment before production deploys
