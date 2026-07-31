# Lux API Reference

Complete reference for all core Lux modules, types, callbacks, and configuration options.

## Core Modules

### Lux (Top-Level)

Module providing reflection utilities for the Lux framework.

```elixir
Lux.beam?(module)     # Check if a module is a Beam
Lux.prism?(module)    # Check if a module is a Prism
Lux.lens?(module)     # Check if a module is a Lens
Lux.hello()           # Returns :world
```

---

## Lux.Agent

Autonomous agent entity. Agents are GenServer processes with signal handling, LLM integration, memory, and scheduled actions.

### Struct Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `id` | `String.t()` | UUID | Unique agent identifier |
| `name` | `String.t()` | `""` | Human-readable name |
| `description` | `String.t()` | `""` | Agent purpose description |
| `goal` | `String.t()` | `""` | Agent's objective |
| `module` | `module()` | `nil` | Implementing module |
| `prisms` | `[Lux.Prism.t()]` | `[]` | Registered prisms |
| `beams` | `[Lux.Beam.t()]` | `[]` | Registered beams |
| `lenses` | `[Lux.Lens.t()]` | `[]` | Registered lenses |
| `accepts_signals` | `[Lux.SignalSchema.t()]` | `[]` | Accepted signal types |
| `llm_config` | `map()` | `%{provider: :openai, model: "gpt-4", temperature: 0.7}` | LLM configuration |
| `memory_config` | `memory_config()` \| `nil` | `nil` | Memory backend config |
| `memory_pid` | `pid()` \| `nil` | `nil` | Memory process PID |
| `scheduled_actions` | `[scheduled_action()]` | `[]` | Periodic actions |
| `signal_handlers` | `[signal_handler()]` | `[]` | Signal handler definitions |
| `template` | `atom()` | `nil` | Behavior template (`:company_agent`) |
| `template_opts` | `map()` | `%{}` | Template options |

### DSL Options

```elixir
use Lux.Agent,
  name: "Agent Name",                    # Human-readable name
  description: "What the agent does",    # Purpose description
  goal: "Agent's objective",            # Goal statement
  id: "custom_id",                      # Override auto-generated UUID
  module: MyModule,                     # Explicit module reference
  llm_config: %{                         # LLM configuration
    provider: :openai,
    model: "gpt-4o-mini",
    temperature: 0.7
  },
  memory_config: %{                     # Memory backend
    backend: Lux.Memory.ETS,
    name: :my_agent_memory
  },
  template: :company_agent,             # Behavior template
  template_opts: %{},                   # Template-specific options
  prisms: [MyPrism],                    # Available prisms
  beams: [MyBeam],                      # Available beams
  lenses: [MyLens],                     # Available lenses
  accepts_signals: [MySignalSchema],    # Accepted signal schemas
  signal_handlers: [{SchemaModule, HandlerModule}],  # Custom handlers
  scheduled_actions: [                  # Periodic actions
    {MyPrism, 60_000, %{task: "analyze"}, []}
  ]
```

### Public Functions

```elixir
Lux.Agent.view()                                # Get agent struct
Lux.Agent.start_link(opts)                      # Start agent process (GenServer)
Lux.Agent.send_message(pid, message, opts)      # Send chat message
Lux.Agent.get_state(pid)                        # Get GenServer state
Lux.Agent.chat(agent, message, opts)            # LLM-powered chat
Lux.Agent.schedule_action(name, mod, ms, i, o)  # Schedule recurring action
Lux.Agent.from_json(source)                     # Create from JSON config
```

### Callbacks

```elixir
@callback chat(t(), message :: String.t(), opts :: keyword()) ::
  {:ok, String.t()} | {:error, term()}
```

---

## Lux.Lens

Declarative HTTP data access. Lenses wrap REST APIs with schema validation, authentication, and automatic response transformation.

### Struct Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | `String.t()` | `""` | Lens name |
| `module_name` | `String.t()` | `""` | Full module name |
| `url` | `String.t()` | `""` | API endpoint URL |
| `method` | `atom()` | `:get` | HTTP method (`:get`, `:post`, `:put`, `:delete`) |
| `params` | `map()` | `%{}` | Query/body parameters |
| `headers` | `list()` | `[]` | HTTP headers |
| `auth` | `map()` \| `nil` | `nil` | Authentication config |
| `description` | `String.t()` | `""` | Lens description |
| `schema` | `map()` | `%{}` | Input parameter schema |
| `after_focus` | `function()` | identity | Response transformation callback |

### DSL Options

```elixir
use Lux.Lens,
  name: "API Name",              # Lens display name
  description: "Description",    # Purpose description
  url: "https://api.example.com/v1/:resource/:id",  # URL with path params
  method: :get,                  # HTTP method
  params: %{default: "value"},   # Default query/body params
  headers: [{"Accept", "application/json"}],  # Default headers
  auth: %{                       # Authentication (optional)
    type: :api_key,              # :api_key | :basic | :oauth | :custom
    key: fn -> System.get_env("API_KEY") end  # Key resolver
  },
  schema: %{                     # Input validation schema
    type: :object,
    properties: %{
      resource: %{type: :string, description: "Resource type"},
      id: %{type: :string, description: "Resource ID", pattern: "^[a-z0-9_-]+$"}
    },
    required: ["resource", "id"]
  }
```

### Authentication Types

| Type | Required Fields | Behavior |
|------|----------------|----------|
| `:api_key` | `key: binary \| (-> binary)` | Adds `Authorization: Bearer <key>` |
| `:basic` | `username, password` | Adds `Authorization: Basic base64(user:pass)` |
| `:oauth` | `token` | Adds `Authorization: Bearer <token>` |
| `:custom` | `auth_function: (Lens -> Lens)` | Calls user-defined function |

### Public Functions

```elixir
MyLens.view()                          # Get lens struct
MyLens.focus(input \\ %{}, opts \\ []) # Execute the lens (HTTP call)
MyLens.after_focus(body)               # Override for response transformation
MyLens.before_focus(params)            # Override for request preprocessing
Lux.Lens.focus(lens, opts)             # Internal execution function
Lux.Lens.authenticate(lens)            # Apply authentication to headers
Lux.Lens.new(attrs)                    # Create lens struct from map/list
```

---

## Lux.Prism

Reusable pure function units. Prisms are composable, schema-validated functions that transform data.

### Struct Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `id` | `String.t()` | `""` | Unique identifier |
| `name` | `String.t()` | `""` | Prism name |
| `module_name` | `String.t()` | `""` | Full module path |
| `handler` | `handler()` | `nil` | Handler function |
| `description` | `String.t()` | `""` | Purpose description |
| `examples` | `[String.t()]` | `[]` | Usage examples |
| `input_schema` | `schema()` \| `nil` | `nil` | Input validation schema |
| `output_schema` | `schema()` \| `nil` | `nil` | Output validation schema |

### DSL Options

```elixir
use Lux.Prism,
  name: "Data Transformer",
  description: "Transforms input data format",
  input_schema: %{
    type: :object,
    properties: %{
      data: %{type: :object, description: "Raw input data"},
      format: %{type: :string, enum: ["json", "xml", "csv"]}
    },
    required: ["data"]
  },
  output_schema: %{
    type: :object,
    properties: %{
      transformed: %{type: :array},
      metadata: %{type: :object}
    }
  },
  examples: [
    "handler(%{data: %{name: 'test'}}, %{format: 'json'})"
  ]
```

### Callbacks

```elixir
@callback handler(input :: any(), context :: any()) ::
  {:ok, any()} | {:error, any()}
```

### Public Functions

```elixir
MyPrism.view()                       # Get prism struct
MyPrism.run(input, context \\ nil)   # Execute the prism
MyPrism.handler(input, context)      # Handler implementation
Lux.Prism.new(attrs)                 # Create prism from map/list
Lux.Prism.run(schema, input, ctx)    # Run prism by module/struct/path
Lux.Prism.resolve_schema(schema)     # Resolve schema references
```

### Python Prisms

```python
# priv/python/my_prism.py
def view():
    return {
        "name": "Python Transformer",
        "description": "Transform data in Python",
        "input_schema": {
            "type": "object",
            "properties": {"data": {"type": "array"}}
        }
    }

def handler(input_data, context):
    result = [item * 2 for item in input_data["data"]]
    return {"ok": True, "doubled": result}
```

```elixir
# Load and use Python prism
Lux.Prism.view("priv/python/my_prism.py")
Lux.Prism.run("priv/python/my_prism.py", %{data: [1, 2, 3]})
```

---

## Lux.Beam

Workflow orchestration combining prisms into sequential, parallel, and conditional execution graphs.

### Struct Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `id` | `String.t()` | `nil` | Beam identifier |
| `name` | `String.t()` | `""` | Beam name |
| `module_name` | `String.t()` | `nil` | Module path |
| `description` | `String.t()` | `""` | Purpose description |
| `input_schema` | `schema()` \| `nil` | `nil` | Input validation |
| `output_schema` | `schema()` \| `nil` | `nil` | Output validation |
| `definition` | `[step()]` | `[]` | Step definitions (set by DSL) |
| `timeout` | `pos_integer()` | `:timer.minutes(5)` | Global timeout |
| `generate_execution_log` | `boolean()` | `false` | Enable execution logging |

### Step Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `timeout` | `pos_integer()` | `:timer.minutes(5)` | Step timeout in ms |
| `retries` | `non_neg_integer()` | `0` | Retry attempts |
| `retry_backoff` | `pos_integer()` | `1000` | Backoff delay in ms |
| `track` | `boolean()` | `false` | Track step in logs |
| `dependencies` | `[String.t()]` | `[]` | Step dependency IDs |
| `store_io` | `boolean()` | `false` | Store input/output in log |
| `fallback` | `module() \| function()` | `nil` | Fallback handler |

### DSL Constructs

```elixir
use Lux.Beam,
  name: "Workflow Name",
  description: "Workflow purpose",
  input_schema: %{...},
  output_schema: %{...},
  timeout: :timer.minutes(10),
  generate_execution_log: true

# Constructs available inside the beam:
sequence do ... end     # Sequential execution
parallel do ... end     # Concurrent execution
branch do ... end       # Conditional branching (requires function)

# Step definition
step(:id, Module, %{param: :value} [, opts])  # Define a step
```

### Parameter References

```elixir
{:ref, "step_id"}           # Reference step output
{:ref, "step_id.nested"}    # Reference nested output field
:input_field                 # Reference beam input field
```

### Public Functions

```elixir
MyBeam.view()                        # Get beam struct
MyBeam.run(input, opts \\ [])        # Execute beam (must return __steps__)
Lux.Beam.new(attrs)                  # Create beam from list
Lux.Beam.validate!(beam)             # Validate beam definition
```

---

## Lux.Signal

Inter-agent message passing with schema validation.

### Struct Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `id` | `String.t()` | `nil` | Signal identifier |
| `payload` | `map()` | `%{}` | Signal content |
| `sender` | `String.t()` \| `nil` | `nil` | Sender agent ID |
| `recipient` | `String.t()` \| `nil` | `nil` | Recipient agent ID |
| `timestamp` | `DateTime.t()` | `nil` | Creation time |
| `topic` | `String.t()` \| `nil` | `nil` | Topic for broadcasting |
| `metadata` | `map()` | `%{}` | Extra metadata |
| `schema_id` | `module()` \| `nil` | `nil` | Schema module |

### Public Functions

```elixir
Lux.Signal.new(attrs)          # Create signal from map
Lux.Signal.validate(signal, schema)  # Validate against schema
```

---

## Lux.SignalSchema

Signal type definitions with validation.

```elixir
defmodule MyApp.Signals.TaskAssignment do
  use Lux.Signal.Schema,
    id: "task_assignment_v1",
    schema: %{
      type: :object,
      properties: %{
        task: %{type: :string, description: "Task description"},
        priority: %{type: :string, enum: ["low", "medium", "high"]},
        due_date: %{type: :string, format: "date-time"}
      },
      required: ["task", "priority"]
    }
end
```

---

## Lux.AgentHub

Central agent registry with capability-based discovery.

```elixir
Lux.AgentHub.start_link(opts)                   # Start hub (GenServer)
Lux.AgentHub.get_default()                      # Get default hub PID
Lux.AgentHub.register(hub, agent, pid, caps)    # Register agent
Lux.AgentHub.update_status(hub, agent_id, status) # Update agent status
Lux.AgentHub.list_agents(hub)                   # List all agents
Lux.AgentHub.find_by_capability(hub, cap)       # Find by capability
Lux.AgentHub.get_agent_info(hub, agent_id)      # Get agent info
```

### Agent Status

- `:available` — Ready to receive tasks
- `:busy` — Currently processing a task
- `:offline` — Process terminated or unresponsive

---

## Lux.Company

Organization-level orchestration of agents, roles, and objectives.

```elixir
Lux.Company.start_link(module, opts)                  # Start company
Lux.Company.run(company, opts)                        # Full startup sequence
Lux.Company.run_objective(company, objective_id, input) # Run objective
Lux.Company.list_roles(company)                       # List roles
Lux.Company.get_role(company, role_id)                # Get role
Lux.Company.assign_agent(company, role_id, agent)     # Assign agent to role
Lux.Company.list_objectives(company)                  # List objectives
Lux.Company.get_objective(company, id)                # Get objective
Lux.Company.get_objective_status(company, id)         # Get objective status
Lux.Company.get_objective_artifacts(company, id)      # Get objective artifacts
Lux.Company.start_objective(company, id)              # Start objective
Lux.Company.complete_objective(company, id)           # Complete objective
Lux.Company.fail_objective(company, id, reason)       # Fail objective
```

---

## Lux.Memory

Agent memory backends for conversation history and context.

```elixir
Lux.Memory.initialize(opts)                  # Initialize memory
Lux.Memory.add(ref, content, type, metadata) # Store entry
Lux.Memory.recent(ref, n)                    # Get n most recent entries
Lux.Memory.window(ref, start, end_time)      # Get entries in time range
Lux.Memory.search(ref, query)               # Search entries
```

### Memory Types

- `:observation` — Fact or data observation
- `:reflection` — Agent's self-reflection
- `:interaction` — Conversation turn
- `:system` — System-level event

### Backends

| Backend | Module | Use Case |
|---------|--------|----------|
| ETS | `Lux.Memory.ETS` | Fast, in-memory (default) |
| Custom | User-defined | Redis, Postgres, DETS |

---

## Lux.LLM

LLM interaction layer with provider abstraction.

```elixir
Lux.LLM.call(prompt, tools, options)
  # => {:ok, %Lux.LLM.Response{content: "..."}}
  # => {:ok, %Lux.Signal{payload: %{tool_calls_results: [...]}}}
  # => {:error, reason}
```

### Response Struct

```elixir
%Lux.LLM.Response{
  content: "Response text" | nil,
  tool_calls: [%{type: "prism", name: "MyPrism", params: %{...}}],
  finish_reason: "stop" | "tool_calls" | "length" | nil,
  structured_output: %{...} | nil
}
```

### Supported Providers

| Provider | Module | Config Key |
|----------|--------|------------|
| OpenAI | `Lux.LLM.OpenAI` | `OPENAI_API_KEY` |
| Anthropic | `Lux.LLM.Anthropic` | `ANTHROPIC_API_KEY` |
| Together AI | `Lux.LLM.Together` | `TOGETHER_API_KEY` |

---

## Lux.Python

Python code execution via Venomous/ErlPort bridge.

```elixir
Lux.Python.eval(code_or_path, opts)
  # Options: :variables, :timeout, :env

# Example: evaluate Python code
Lux.Python.eval("x * 2", variables: %{x: 21})
# => {:ok, 42}

# Example: load and execute Python file
Lux.Python.eval("priv/python/my_script.py",
  variables: %{data: [1, 2, 3]})
```

---

## Lux.NodeJS

Node.js code execution bridge.

```elixir
Lux.NodeJS.eval(script, opts)
```

---

## Telemetry Events

Lux emits standard Telemetry events for observability:

| Event | Measurements | Metadata |
|-------|-------------|----------|
| `[:lux, :agent, :lifecycle]` | `duration` | `agent_id, event_type` |
| `[:lux, :beam, :step]` | `duration, status` | `beam_id, step_id, step_name` |
| `[:lux, :signal, :dispatch]` | `duration` | `schema_id, sender, recipient` |
| `[:lux, :lens, :request]` | `duration, status_code` | `lens_name, url, method` |
| `[:lux, :llm, :completion]` | `duration, tokens, prompt_tokens, completion_tokens` | `provider, model, agent_id` |
