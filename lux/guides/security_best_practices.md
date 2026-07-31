# Security Best Practices

This guide outlines security considerations and best practices when building and deploying applications with the Lux framework.

## API Key Management

### Never Hardcode Credentials

Always use environment variables or a secrets manager for API keys:

```elixir
# GOOD: Runtime resolution from environment
config :lux, Lux.Integrations.OpenAI,
  api_key: {:system, "OPENAI_API_KEY"}

# BAD: Hardcoded key
config :lux, Lux.Integrations.OpenAI,
  api_key: "sk-proj-abc123..."
```

### Key Rotation

Implement automated key rotation for LLM providers:

1. Generate new API keys in your provider's dashboard
2. Store new keys in your secrets manager
3. Deploy with both old and new keys simultaneously (dual-key window)
4. Remove old keys after agents have migrated

### Provider-Specific Key Scoping

- **OpenAI**: Use project-scoped API keys, not account-level keys
- **Anthropic**: Create workspace-specific keys with usage limits
- **Together AI**: Set spending caps per key
- **Custom providers**: Rotate keys every 90 days

Restrict each key to only the models and endpoints needed by your agents.

## Signal Security

### Signal Authentication

For multi-tenant or multi-user deployments, authenticate signals:

```elixir
defmodule MyApp.SignalAuth do
  def authenticate(%Lux.Signal{metadata: %{auth_token: token}}) do
    case verify_token(token) do
      {:ok, claims} -> {:ok, claims}
      {:error, reason} -> {:error, :unauthorized}
    end
  end

  defp verify_token(token) do
    # JWT verification or similar
    MyApp.Token.verify(token)
  end
end
```

### Input Validation

Every signal content should be validated against its schema:

```elixir
# Built-in protection: signals are validated at dispatch time
defmodule MySignalSchema do
  use Lux.Signal.Schema,
    id: "task_assignment_v1",
    schema: %{
      type: :object,
      properties: %{
        task: %{type: :string, max_length: 10_000},
        priority: %{type: :string, enum: ["low", "medium", "high"]},
        assignee: %{type: :string, pattern: "^agent_[a-z0-9_]+$"}
      },
      required: ["task", "assignee"]
    }
end
```

Key validation rules:
- Enforce string length limits to prevent memory exhaustion
- Use enum constraints for restricted fields
- Apply regex patterns for structured identifiers
- Reject unexpected fields in strict mode

### Rate Limiting

Protect agents from signal flooding:

```elixir
# Per-agent rate limiting using Hammer
defmodule MyAgent do
  use Lux.Agent

  def handle_signal(signal, state) do
    case Hammer.check_rate("agent:#{state.id}", 100, 60_000) do
      {:allow, _count} -> process_signal(signal, state)
      {:deny, _retry_after} -> {:error, :rate_limited}
    end
  end
end
```

Configure appropriate limits:
- 100 signals/minute for standard agents
- 10 signals/minute for LLM-heavy agents (cost control)
- 1000 signals/minute for simple relay agents

## LLM Security

### Prompt Injection Prevention

LLM-powered agents are vulnerable to prompt injection. Mitigations:

1. **Input Sanitization**: Strip or escape control characters and markdown from user inputs before sending to LLMs

2. **System Prompt Hardening**: Place system instructions at the end of prompts with explicit priority markers

3. **Output Validation**: Validate LLM outputs against expected schemas before acting on them

```elixir
def sanitize_input(user_input) do
  user_input
  |> String.replace(~r/\[SYSTEM\]|\[OVERRIDE\]|\[IGNORE\]/i, "[FILTERED]")
  |> String.slice(0, 4_000)
end

def validate_llm_output(output, expected_schema) do
  case ExJsonSchema.Validator.validate(expected_schema, output) do
    :ok -> {:ok, output}
    {:error, errors} -> {:error, "LLM output validation failed: #{inspect(errors)}"}
  end
end
```

4. **Tool Restriction**: Limit which tools/lenses an LLM-powered agent can invoke based on its role

5. **Sandbox Execution**: Run LLM-generated code in isolated environments (separate BEAM nodes, containers)

### Data Minimization

Only send necessary data to LLMs:

- Strip PII (names, emails, phone numbers) from context before LLM calls
- Avoid sending full conversation histories; summarize or truncate
- Use local prisms for data processing instead of sending raw data to LLMs
- Implement data retention policies for LLM request/response logs

### Token Usage Monitoring

Track and alert on anomalous token consumption:

```elixir
:telemetry.attach("llm-cost-monitor", [:lux, :llm, :completion], fn _event, measurements, metadata, _config ->
  if measurements.tokens > 100_000 do
    Logger.warning("High token usage: #{measurements.tokens} tokens by agent #{metadata.agent_id}")
    # Send alert to monitoring system
  end
end, nil)
```

## Lens Security (External API Calls)

### URL Validation

Prevent Server-Side Request Forgery (SSRF) in lenses:

```elixir
def validate_url(url) do
  uri = URI.parse(url)
  
  # Block internal/private IPs
  if private_ip?(uri.host) do
    {:error, :ssrf_blocked}
  else
    {:ok, url}
  end
end

defp private_ip?(host) do
  case :inet.parse_address(String.to_charlist(host)) do
    {:ok, {127, _, _, _}} -> true
    {:ok, {10, _, _, _}} -> true
    {:ok, {172, second, _, _}} when second in 16..31 -> true
    {:ok, {192, 168, _, _}} -> true
    {:ok, {169, 254, _, _}} -> true
    _ -> false
  end
end
```

### TLS Enforcement

Force HTTPS for all production lenses:

```elixir
config :lux, :lens_security,
  require_tls: true,
  allowed_schemes: ["https"],
  timeout: 30_000
```

### Response Size Limits

Prevent memory exhaustion from large API responses:

```elixir
defp body_or_params(:get, params), do: [params: params, max_body_length: 10_000_000]
```

## Agent Sandboxing

### Capability-Based Access Control

Restrict agents to only the capabilities they need:

```elixir
has_member "Data Analyst" do
  agent(MyApp.Agents.Analyst)
  goal("Analyze market data")
  can("analyze_data")        # Allowed
  can("fetch_market_data")   # Allowed
  # NOT allowed: "execute_trade", "transfer_funds"
end
```

The execution engine enforces capability checks before delegating tasks.

### Network Isolation

For high-security deployments, run sensitive agents in isolated network segments:

```elixir
config :lux, :agent_isolation,
  network_segments: %{
    trading: [allowed_domains: ["api.exchange.com"]],
    research: [allowed_domains: ["api.news.org", "api.weather.gov"]],
    admin:   [allowed_domains: ["*"]]
  }
```

## Audit Logging

### Immutable Audit Trail

Log all sensitive operations for compliance:

```elixir
def log_audit_event(event_type, metadata) do
  entry = %{
    event: event_type,
    timestamp: DateTime.utc_now(),
    agent_id: metadata[:agent_id],
    company_id: metadata[:company_id],
    action: metadata[:action],
    resource: metadata[:resource],
    result: metadata[:result],
    ip_address: metadata[:ip_address]
  }
  
  # Write to append-only log or database
  AuditLog.append(entry)
end
```

Events to audit:
- Agent creation and termination
- Objective execution (start, step completion, finish)
- Signal dispatch between agents
- LLM API calls with token counts
- External API calls with status codes
- Configuration changes

## Incident Response

### Agent Quarantine

If an agent exhibits anomalous behavior, quarantine it:

```elixir
# Stop signal processing but preserve state for forensics
Lux.AgentHub.quarantine("agent_suspicious_1")

# Move to analysis environment
Lux.AgentHub.migrate("agent_suspicious_1", :analysis_hub)
```

### Rollback Procedures

1. Identify the problematic deployment or configuration change
2. Stop affected agents via AgentHub
3. Revert to the last known-good configuration
4. Restart agents with the reverted configuration
5. Analyze logs and agent state for root cause
6. Apply fix and redeploy

## Dependency Management

### Supply Chain Security

- Pin all Hex dependencies with specific versions in `mix.lock`
- Use `mix hex.audit` to check for known vulnerabilities
- Review dependency licenses for compliance
- Prefer dependencies with active maintenance and security track records

```bash
# Regular security audit
mix hex.audit
mix deps.audit

# Check for outdated dependencies
mix hex.outdated
```

### Python Package Security

For Python dependencies:
- Pin exact versions in `requirements.txt` with hashes
- Use `pip-audit` or `safety check` for vulnerability scanning
- Prefer official PyPI packages over unverified sources

```bash
pip-audit -r priv/python/requirements.txt
```

## Secure Configuration Checklist

Before deploying to production, verify:

- [ ] All API keys loaded from environment variables or secrets manager
- [ ] Signal schemas include input length limits
- [ ] Rate limiting configured for all agents
- [ ] URL validation prevents SSRF in lenses
- [ ] TLS enforced for all external API calls
- [ ] LLM output validation enabled
- [ ] PII stripping configured before LLM calls
- [ ] Audit logging active for all sensitive operations
- [ ] Agent capabilities follow principle of least privilege
- [ ] `SECRET_KEY_BASE` generated and stored securely
- [ ] Production `MIX_ENV=prod` set
- [ ] Hex audit and dependency checks passing
- [ ] Docker images scanned for vulnerabilities
- [ ] Incident response playbook documented
