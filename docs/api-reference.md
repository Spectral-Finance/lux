# API Reference

## Overview
Lux provides a RESTful API for agent orchestration and monitoring.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/agents` | List all agents |
| POST | `/api/v1/agents` | Create new agent |
| GET | `/api/v1/agents/{id}` | Get agent details |
| DELETE | `/api/v1/agents/{id}` | Remove agent |
| POST | `/api/v1/agents/{id}/run` | Execute agent task |
| GET | `/api/v1/agents/{id}/logs` | Stream agent logs |
| GET | `/api/v1/metrics` | System metrics |
| GET | `/health` | Health check |

## Agent Object
```typescript
interface Agent {
  id: string;
  name: string;
  status: 'idle' | 'running' | 'error' | 'stopped';
  config: AgentConfig;
  metrics: AgentMetrics;
  created_at: string;
  updated_at: string;
}
```

## Authentication
All requests require `Authorization: Bearer <token>` header.
```bash
curl -H "Authorization: Bearer $LUX_TOKEN" https://api.lux.dev/api/v1/agents
```

## Rate Limiting
- 100 requests/minute per token
- 429 status returned when exceeded
- `Retry-After` header indicates wait time

## Error Responses
```json
{
  "error": {
    "code": "AGENT_NOT_FOUND",
    "message": "Agent with id 'xyz' not found",
    "details": {}
  }
}
```

## Webhooks
Configure webhooks for agent lifecycle events:
- `agent.created`
- `agent.started`
- `agent.completed`
- `agent.failed`

## SDK Examples

### Python
```python
from lux import LuxClient

client = LuxClient(token="your-token")
agents = client.list_agents()
agent = client.create_agent(
    name="my-agent",
    task="process data",
    config={"timeout": 300}
)
result = client.run_agent(agent.id)
```

### TypeScript
```typescript
import { LuxClient } from '@spectral-finance/lux-sdk';

const client = new LuxClient({ token: 'your-token' });
const agents = await client.listAgents();
const agent = await client.createAgent({
  name: 'my-agent',
  task: 'process data',
  config: { timeout: 300 }
});
const result = await client.runAgent(agent.id);
```

## Metrics
```yaml
agent_requests_total: Total agent requests
agent_duration_seconds: Task duration histogram
agent_errors_total: Error count by type
agent_active_count: Currently running agents
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| 401 Unauthorized | Verify token in `Authorization` header |
| 429 Rate limited | Check `Retry-After`, reduce frequency |
| 503 Service unavailable | API under maintenance, retry with backoff |
| Timeout | Increase `timeout` in agent config |
