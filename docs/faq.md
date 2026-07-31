# Frequently Asked Questions

## General

**Q: What is Lux?**
A: Lux is an autonomous agent orchestration platform that manages the lifecycle of AI agents including creation, execution, monitoring, and cleanup.

**Q: What agents does Lux support?**
A: Any agent that implements the `Agent` interface. Built-in support for web agents, CLI agents, and custom signal processors.

## Configuration

**Q: How do I increase the max concurrent agents?**
A: Set `LUX_MAX_AGENTS` env variable or configure in `config/lux.yaml`:
```yaml
runtime:
  max_concurrent_agents: 20
```

**Q: Can I use a different database?**
A: Yes. Set `LUX_DB_PATH` to a PostgreSQL connection string:
```bash
export LUX_DB_PATH="postgres://user:pass@localhost:5432/lux"
```

## Performance

**Q: How many agents can Lux handle simultaneously?**
A: Default 10. Tested up to 50 on 4-core/8GB. Each agent uses ~50MB RAM.

**Q: My agent is slow. How do I debug?**
A: Enable debug logging: `LUX_LOG_LEVEL=debug`. Check agent logs at `/api/v1/agents/{id}/logs`.

## Security

**Q: Is authentication required?**
A: Yes since v1.1.0. Set `LUX_AUTH_TOKEN` env var and pass it as `Authorization` header.

**Q: Can I run Lux without internet?**
A: Yes. Lux works fully offline. Only SDK downloads and webhook delivery need network.

## Troubleshooting

**Q: "Agent limit reached" error?**
A: Increase `LUX_MAX_AGENTS` or stop idle agents.

**Q: Database locked error?**
A: Delete `./data/lux.lock` file or restart with a fresh DB path.
