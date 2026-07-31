# Lux Architecture Deep Dive

This document provides a comprehensive architectural overview of the Lux framework, covering the internal design patterns, data flow, process model, and extensibility points.

## High-Level Architecture

Lux follows a layered architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────┐
│              APPLICATION LAYER              │
│  (Companies, Custom Agents, Workflows)      │
├─────────────────────────────────────────────┤
│            ORCHESTRATION LAYER              │
│  Beams (Workflows), AgentHub (Registry)     │
├─────────────────────────────────────────────┤
│              COMPONENT LAYER                │
│  Agents, Prisms, Lenses, Signals            │
├─────────────────────────────────────────────┤
│             INFRASTRUCTURE LAYER            │
│  LLM Integration, HTTP, Python/Node Bridges │
└─────────────────────────────────────────────┘
```

### Layer Responsibilities

**Application Layer**: User-defined companies, custom agent implementations, and domain-specific workflows. This is where business logic lives.

**Orchestration Layer**: Beam-based workflow orchestration, the AgentHub registry for agent discovery, and execution engines that coordinate multi-agent collaboration.

**Component Layer**: The four core abstractions — Agents (autonomous entities), Prisms (pure functions), Lenses (external data access), and Signals (typed messages). Each is designed for composition and testability.

**Infrastructure Layer**: LLM provider adapters (OpenAI, Anthropic, Together AI), HTTP client (Req-based), Python bridge (ErlPort/Venomous), and Node.js integration.

## The Agent Lifecycle

### 1. Definition and Compilation
Agents are defined using `use Lux.Agent` or `use Lux.Agent.Base` with compile-time configuration:

```elixir
defmodule MyAgent do
  use Lux.Agent,
    name: "My Agent",
    description: "Handles specific domain tasks",
    goal: "Achieve task objectives efficiently",
    llm: %{provider: :openai, model: "gpt-4o-mini"}
end
```

At compile time, the DSL macros extract configuration into module attributes and generate:
- A `view/0` function returning the agent struct
- Signal handler dispatch logic
- Lifecycle callback stubs

### 2. Supervision and Registration
Agents are supervised processes under `Lux.Agent.Supervisor`. When started via `Lux.AgentHub.start_agent/2`:

1. The supervisor spawns a GenServer process
2. The agent registers with its designated AgentHub
3. The hub broadcasts the agent's capabilities to peers
4. Other agents can discover and communicate with it

### 3. Runtime Execution Loop
Each agent process runs a receive loop that:
1. Listens for incoming signals from peers
2. Delegates signal handling to registered handlers (Prisms, Lenses, or custom logic)
3. Optionally invokes LLM reasoning for decision-making
4. Emits response signals back to callers
5. Updates internal state (memory, context)

### 4. Graceful Shutdown
When terminated:
1. The supervisor traps exits
2. The agent saves state to the configured memory backend
3. It broadcasts a `:agent_offline` status
4. The hub deregisters it from the registry
5. In-flight signals are either completed or failed with appropriate errors

## Signal Bus Architecture

Signals are the backbone of inter-agent communication. The architecture ensures type safety and schema validation at every hop.

### Signal Structure
```elixir
%Lux.Signal{
  id: "sig_abc123",
  schema_id: "task_assignment_v1",
  content: %{task: "...", priority: :high},
  from: "agent_researcher_1",
  to: "agent_writer_1",
  correlation_id: "corr_xyz",
  timestamp: ~U[2025-01-15 12:00:00Z],
  metadata: %{ttl: 300}
}
```

### Signal Flow
```
Agent A                    AgentHub                  Agent B
  │                          │                         │
  │──emit(signal)───────────▶│                         │
  │                          │──validate_schema()      │
  │                          │──resolve_target()       │
  │                          │──dispatch()────────────▶│
  │                          │                         │──handle_signal()
  │                          │                         │──process()
  │                          │◀────response────────────│
  │◀────deliver(response)────│                         │
```

### Schema Validation
Every signal is validated against its declared schema at dispatch time:
- Type checking for all fields
- Required field enforcement
- Nested object validation
- Enum constraint checking for restricted fields

Invalid signals are rejected with detailed error messages, preventing silent data corruption.

## Beam Execution Engine

### AST-Based Workflow Representation
Beams compile to an internal AST (Abstract Syntax Tree) before execution:

```elixir
# User code:
sequence do
  step(:fetch, FetchPrism, %{url: :input_url})
  parallel do
    step(:analyze, AnalyzePrism, %{data: {:ref, "fetch"}})
    step(:summarize, SummarizePrism, %{data: {:ref, "fetch"}})
  end
end

# Internal AST:
{:sequence, [
  %{id: :fetch, module: FetchPrism, params: %{url: :input_url}},
  {:parallel, [
    %{id: :analyze, module: AnalyzePrism, params: %{data: {:ref, "fetch"}}},
    %{id: :summarize, module: SummarizePrism, params: %{data: {:ref, "fetch"}}}
  ]}
]}
```

### Execution Strategy
The `Lux.Beam.Runner` module walks the AST using a recursive interpreter:

1. **Sequences**: Steps execute one after another, each receiving the accumulated context
2. **Parallel blocks**: Steps run concurrently via `Task.async_stream`, with configurable timeouts
3. **Branches**: A condition function evaluates the current context; the matching branch executes

### Context Propagation
Each step's output is merged into an execution context map. References use the `{:ref, "step_id"}` syntax to resolve outputs from prior steps. Dot-notation paths (`"step_id.nested.key"`) traverse nested maps.

### Error Handling and Retries
- Individual steps can declare `retries` and `retry_backoff`
- Failed steps trigger `fallback` handlers if configured
- Execution logs capture timing, inputs, outputs, and errors for debugging
- Timeout configuration prevents indefinite hangs

## Company Execution Engine

Companies use the `Lux.Company.ExecutionEngine` subsystem:

### Components
- **ObjectiveProcess**: A GenServer that manages the lifecycle of a single objective execution
- **TaskTracker**: Tracks progress of individual steps within an objective
- **ArtifactStore**: Persists intermediate outputs (text, images, data) generated during execution
- **Supervisor**: DynamicSupervisor that spawns ObjectiveProcess instances on demand

### Execution Flow
1. `Lux.Company.run_objective/3` creates an `ObjectiveProcess` under the company's supervisor
2. The CEO agent receives the objective and decomposes it into tasks
3. Tasks are dispatched to member agents based on capability matching
4. Each member agent executes its assigned task using its configured LLM and tools
5. Results flow back through the CEO for approval/iteration
6. Upon completion, the success criteria are evaluated
7. Artifacts are stored and the objective process terminates

### Capability-Based Routing
The CEO matches tasks to members by comparing required capabilities:
- Each member declares capabilities via `can/1` in the DSL
- The execution engine builds a capability index at startup
- Tasks include a `requires` field listing needed capabilities
- The CEO selects the best-matched member for each task

## Multi-Language Bridge

### Python Integration (Venomous/ErlPort)
The Python bridge uses ErlPort with Venomous process management:

```
Elixir Process                  Python Process
      │                              │
      │──ErlPort.call(python, fn, args)──▶
      │                              │──execute function
      │◀───────return value──────────│
```

- **Worker Pool**: Venomous manages a pool of Python worker processes
- **TTL Management**: Idle workers are recycled after a configurable TTL
- **Module Paths**: Python modules live under `priv/python/`
- **Serialization**: Data is serialized via ErlPort's term format (not JSON, avoiding overhead)

### Node.js Integration
The Node.js bridge uses the `nodejs` Hex package:
- JavaScript modules under `priv/node/`
- Asynchronous execution via Node.js worker threads
- JSON serialization for data exchange

## Configuration System

Lux uses a layered configuration approach:

1. **Compile-time**: Module attributes in `config/config.exs`
2. **Runtime**: Environment variables and `config/runtime.exs`
3. **Per-provider**: Provider-specific configs (`config/anthropic.exs`, etc.)
4. **Agent-level**: Individual agent LLM configs override defaults

### LLM Provider Configuration
```elixir
# Default models
config :lux, :open_ai_models,
  cheapest: "gpt-4o-mini",
  default: "gpt-4o-mini",
  smartest: "gpt-4o"

# Provider credentials are loaded at runtime
config :lux, Lux.Integrations.OpenAI,
  api_key: {:system, "OPENAI_API_KEY"}
```

The `{:system, "ENV_VAR"}` tuple defers resolution to runtime, keeping secrets out of compiled code.

## Extensibility Points

### Custom Prisms
Implement the `handler/2` callback:
```elixir
defmodule MyPrism do
  def handler(params, ctx) do
    # Process params with access to execution context
    {:ok, result}
  end
end
```

### Custom Lenses
Use `use Lux.Lens` with URL, method, and schema. Override `after_focus/1` for response transformation and `before_focus/1` for request preprocessing.

### Custom Signal Handlers
Agents can register additional signal handlers via the `Lux.Agent.Companies.SignalHandler` behaviour, enabling domain-specific message processing.

### Custom LLM Providers
Add new providers by implementing the LLM adapter protocol and registering them in the configuration system.

## Process Supervision Tree

```
Lux.Application
├── Lux.AgentHub (Registry + PubSub)
├── Lux.Agent.Supervisor (DynamicSupervisor)
│   ├── Agent GenServer 1
│   ├── Agent GenServer 2
│   └── ...
├── Lux.Company.ExecutionEngine.Supervisor
│   ├── ObjectiveProcess 1
│   └── ...
└── Lux.Integrations.* (optional integration servers)
```

This supervision tree ensures fault isolation: a crashing agent doesn't take down the hub, and a failing objective doesn't crash the company supervisor.

## Memory and State Management

Agents support configurable memory backends:
- **In-Memory (default)**: ETS-based, fast but ephemeral
- **Disk-Based**: DETS or file-based persistence
- **External**: Redis, Postgres (via custom adapters)

Memory stores conversation history, task context, and learned patterns, enabling agents to improve over time through reflection.

## Observability

- **Telemetry Events**: All major operations emit `:telemetry` events for metrics collection
- **Execution Logs**: Beams with `generate_execution_log: true` produce detailed JSON logs
- **Agent Status**: Real-time status tracking (online, busy, offline) via AgentHub
- **Error Reporting**: Structured error tuples with context for debugging

## Security Considerations

See the [Security Best Practices Guide](security_best_practices.md) for a comprehensive security overview covering API key management, signal authentication, input validation, and sandboxing recommendations.
