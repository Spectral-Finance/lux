# Comprehensive Testing Guide

This guide covers end-to-end testing strategies for Lux-based applications, including agent testing, beam workflow testing, lens integration testing, and performance/load testing.

## Test Architecture Overview

Lux's test architecture is built on ExUnit with custom test case modules:

```
test/
├── unit/              # Fast, isolated tests (no external services)
│   ├── lux/           # Core framework tests
│   └── support/       # Test helpers and factories
├── integration/       # Tests requiring external services
│   └── support/       # Integration test helpers
└── support/           # Shared test utilities
    ├── conn_case.ex   # Phoenix connection helpers
    └── data_case.ex   # Database helpers
```

### Test Case Modules

| Module | Use When | Requires |
|--------|----------|----------|
| `UnitCase` | Testing prisms, beams, agents in isolation | Nothing |
| `IntegrationCase` | Testing with real LLM APIs, external services | API keys in `test.override.envrc` |
| `UnitAPICase` | Mocking HTTP requests in lenses | Mock/Mox setup |

## Agent Testing

### Unit Testing Agent Behavior

```elixir
defmodule MyApp.Agents.ResearchAgentTest do
  use UnitCase, async: true

  setup do
    {:ok, agent_pid} = MyApp.Agents.ResearchAgent.start_link(
      name: "test_researcher",
      goal: "Find relevant research papers"
    )
    %{agent: agent_pid}
  end

  test "agent registers with AgentHub on startup", %{agent: agent} do
    agent_state = :sys.get_state(agent)
    assert agent_state.name == "test_researcher"
  end

  test "agent responds to chat messages", %{agent: agent} do
    {:ok, response} = GenServer.call(agent, {:chat, "What is your goal?", []})
    assert is_binary(response)
  end

  test "agent handles invalid input gracefully", %{agent: agent} do
    {:ok, response} = GenServer.call(agent, {:chat, "", []})
    refute match?({:error, _}, response)
  end
end
```

### Testing Signal Handling

```elixir
defmodule MyApp.Agents.SignalHandlerTest do
  use UnitCase, async: true

  alias Lux.Signal

  test "processes task_assignment signal correctly" do
    agent = MyApp.Agents.WorkerAgent.view()

    signal = %Signal{
      id: Lux.UUID.generate(),
      schema_id: "task_assignment_v1",
      payload: %{"task" => "analyze_market", "priority" => "high"},
      sender: "ceo_agent",
      recipient: agent.id
    }

    result = MyApp.Agents.WorkerAgent.handle_signal(signal, agent)
    assert {:ok, _} = result
  end

  test "ignores unknown signal schemas" do
    agent = MyApp.Agents.WorkerAgent.view()

    signal = %Signal{
      id: Lux.UUID.generate(),
      schema_id: "unknown_schema_v999",
      payload: %{"data" => "test"},
      sender: "unknown",
      recipient: agent.id
    }

    result = MyApp.Agents.WorkerAgent.handle_signal(signal, agent)
    assert result == :ignore
  end
end
```

### Testing Agent Memory

```elixir
defmodule MyApp.Agents.MemoryTest do
  use UnitCase, async: false

  test "agent stores and retrieves conversation history" do
    {:ok, memory} = Lux.Memory.initialize(backend: Lux.Memory.ETS)

    Lux.Memory.add(memory, "User asked about weather", :interaction, %{role: :user})

    {:ok, recent} = Lux.Memory.recent(memory, 5)
    assert length(recent) > 0
    assert hd(recent).content =~ "weather"
  end

  test "agent memory respects max_context limit" do
    {:ok, memory} = Lux.Memory.initialize(backend: Lux.Memory.ETS)

    # Add 20 entries, but only retrieve last 3
    Enum.each(1..20, fn i ->
      Lux.Memory.add(memory, "Message #{i}", :interaction, %{role: :user})
    end)

    {:ok, recent} = Lux.Memory.recent(memory, 3)
    assert length(recent) == 3
  end
end
```

## Beam Workflow Testing

### Testing Beam Execution

```elixir
defmodule MyApp.Beams.DataPipelineTest do
  use UnitCase, async: true

  test "beam executes sequential steps in order" do
    input = %{raw_data: [1, 2, 3]}

    {:ok, result} = MyApp.Beams.DataPipeline.run(input, return_log: true)

    assert result.processed_count == 3
    assert result.status == :completed
  end

  test "beam handles step failure with fallback" do
    input = %{raw_data: []}  # Empty data triggers fallback

    {:ok, result} = MyApp.Beams.DataPipeline.run(input)

    assert result.status == :partial
    assert result.warnings == ["empty_input_handled_by_fallback"]
  end

  test "beam respects step timeout" do
    input = %{raw_data: [:slow_operation]}

    {:error, reason} = MyApp.Beams.DataPipeline.run(input, timeout: 100)

    assert reason =~ "timeout"
  end
end
```

### Testing Parallel Beam Steps

```elixir
defmodule MyApp.Beams.ParallelWorkflowTest do
  use UnitCase, async: true

  test "parallel steps execute concurrently" do
    start_time = System.monotonic_time(:millisecond)

    {:ok, result} = MyApp.Beams.MultiSourceDataBeam.run(%{
      cities: ["Paris", "London", "Tokyo"]
    })

    elapsed = System.monotonic_time(:millisecond) - start_time

    # Parallel execution should be faster than sequential
    assert elapsed < 3_000
    assert length(result.results) == 3
  end

  test "partial failure in parallel doesn't block others" do
    {:ok, result} = MyApp.Beams.ResilientParallelBeam.run(%{
      sources: [:valid_api, :failing_api, :valid_api]
    })

    assert result.successful == 2
    assert result.failed == 1
  end
end
```

### Testing Branch Logic

```elixir
defmodule MyApp.Beams.BranchingTest do
  use UnitCase, async: true

  test "branch condition routes to correct path" do
    # High score should route to execute_trade
    {:ok, result} = MyApp.Beams.TradingStrategyBeam.run(%{
      signal_score: 0.85, amount: 1000
    })
    assert result.action == :trade_executed

    # Low score should route to skip
    {:ok, result} = MyApp.Beams.TradingStrategyBeam.run(%{
      signal_score: 0.3, amount: 1000
    })
    assert result.action == :trade_skipped
  end
end
```

## Lens Integration Testing

### HTTP Mocking with Bypass

```elixir
defmodule MyApp.Lenses.ExternalAPILensTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    %{bypass: bypass, base_url: "http://localhost:#{bypass.port}"}
  end

  test "lens handles successful API response", %{bypass: bypass} do
    Bypass.expect(bypass, "GET", "/api/v1/data", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"status": "ok", "data": {"value": 42}}))
    end)

    result = MyApp.Lenses.DataLens.focus(%{endpoint: "/api/v1/data"})
    assert {:ok, %{value: 42}} = result
  end

  test "lens handles rate limiting", %{bypass: bypass} do
    Bypass.expect(bypass, "GET", "/api/v1/data", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(429, ~s({"error": "rate_limited", "retry_after": 30}))
    end)

    result = MyApp.Lenses.DataLens.focus(%{endpoint: "/api/v1/data"})
    assert {:error, error} = result
    assert error =~ "rate_limited"
  end

  test "lens handles network timeout", %{bypass: bypass} do
    Bypass.expect(bypass, "GET", "/api/v1/data", fn conn ->
      Process.sleep(10_000)
      Plug.Conn.resp(conn, 200, "")
    end)

    result = MyApp.Lenses.DataLens.focus(%{endpoint: "/api/v1/data"},
      timeout: 100
    )
    assert {:error, _} = result
  end

  test "lens validates response schema" do
    {:error, reason} = MyApp.Lenses.WeatherLens.focus(%{q: "", appid: "test"})
    assert reason =~ "validation"
  end
end
```

### Auth Testing

```elixir
defmodule MyApp.Lenses.AuthLensTest do
  use ExUnit.Case, async: true

  test "lens adds bearer token to request headers" do
    lens = Lux.Lens.new(
      name: "Auth Test",
      url: "https://api.example.com/v1/data",
      method: :get,
      auth: %{type: :api_key, key: fn -> "test_token_abc123" end}
    )

    authenticated = Lux.Lens.authenticate(lens)
    assert Enum.any?(authenticated.headers, fn {k, v} ->
      k == "Authorization" && v == "Bearer test_token_abc123"
    end)
  end

  test "lens with basic auth encodes credentials correctly" do
    lens = Lux.Lens.new(
      name: "Basic Auth",
      url: "https://api.example.com/v1/data",
      method: :get,
      auth: %{type: :basic, username: "admin", password: "secret"}
    )

    authenticated = Lux.Lens.authenticate(lens)
    assert Enum.any?(authenticated.headers, fn {k, v} ->
      k == "Authorization" && String.starts_with?(v, "Basic ")
    end)
  end
end
```

## Prism Testing

```elixir
defmodule MyApp.Prisms.ETLTransformerTest do
  use UnitCase, async: true

  test "prism transforms data correctly" do
    input = %{data: %{id: 1, name: "test", value: 100, timestamp: ~U[2025-01-01 00:00:00Z]}}

    {:ok, result} = MyApp.Prisms.ETLTransformer.handler(input, %{pipeline: :production})

    assert result.external_id == 1
    assert result.label == "TEST"
    assert Decimal.positive?(result.amount)
  end

  test "prism validates output schema" do
    input = %{data: %{id: nil, name: "", value: -1, timestamp: nil}}

    {:ok, result} = MyApp.Prisms.ETLTransformer.handler(input, %{})
    assert result.warning == "non_positive_amount"
  end

  test "prism raises on invalid input type" do
    assert_raise FunctionClauseError, fn ->
      MyApp.Prisms.ETLTransformer.handler(%{data: "invalid"}, %{})
    end
  end
end
```

## Python Prism Testing

```elixir
defmodule Lux.PythonPrismTest do
  use UnitCase, async: true

  test "python prism executes and returns result" do
    {:ok, result} = Lux.Python.eval("x * 2", variables: %{x: 21})
    assert result == 42
  end

  test "python prism handles import errors gracefully" do
    {:error, reason} = Lux.Python.eval("import nonexistent_module_xyz")
    assert reason =~ "ModuleNotFoundError"
  end

  test "python prism respects timeout" do
    code = """
    import time
    time.sleep(10)
    x
    """

    {:error, reason} = Lux.Python.eval(code,
      variables: %{x: 1},
      timeout: 100
    )
    assert reason =~ "timeout"
  end
end
```

## Performance and Load Testing

### Benchmarking Beams

```elixir
defmodule MyApp.Benchmarks.BeamBench do
  use BencheeDsl.Benchmark

  setup do
    %{input: %{records: Enum.to_list(1..10_000)}}
  end

  test "benchmark sequential vs parallel processing", %{input: input} do
    %{
      "sequential" => fn ->
        MyApp.Beams.SequentialProcessor.run(input)
      end,
      "parallel" => fn ->
        MyApp.Beams.ParallelProcessor.run(input)
      end
    }
  end
end
```

### Load Testing Agents

```elixir
defmodule MyApp.LoadTests.AgentLoadTest do
  use ExUnit.Case, async: false

  @tag :load
  test "agent handles 100 concurrent signals" do
    {:ok, hub} = Lux.AgentHub.start_link(name: :load_test_hub)
    {:ok, agent} = MyApp.Agents.WorkerAgent.start_link(name: :load_test_agent)

    Lux.AgentHub.register(hub, MyApp.Agents.WorkerAgent.view(), agent, [:test])

    tasks = for i <- 1..100 do
      Task.async(fn ->
        signal = %Lux.Signal{
          id: Lux.UUID.generate(),
          schema_id: "test_signal_v1",
          payload: %{"index" => i, "data" => "load_test_message"},
          sender: "test_runner",
          recipient: "load_test_agent"
        }
        send(agent, {:signal, signal})
        {:ok, :sent}
      end)
    end

    results = Task.await_many(tasks, 30_000)

    # All signals should be processed
    agent_info = Lux.AgentHub.get_agent_info(hub, "load_test_agent")
    assert {:ok, %{status: :available}} = agent_info

    Enum.each(results, fn {:ok, :sent} -> :ok end)
  end
end
```

## Test Coverage

### Running Coverage

```bash
# Generate HTML coverage report
mix coveralls.html

# Generate coverage for CI
mix coveralls.github

# Show coverage summary in terminal
mix coveralls
```

### Coverage Targets

| Component | Target Coverage | Critical Areas |
|-----------|----------------|----------------|
| Agents | 90%+ | Signal handling, lifecycle, error recovery |
| Beams | 85%+ | All execution paths, branch conditions, retries |
| Prisms | 95%+ | Handler logic, input/output validation |
| Lenses | 85%+ | HTTP responses, auth, error handling |
| Python Bridge | 80%+ | Execution, error propagation, timeouts |

## Continuous Integration Testing

The CI pipeline (`.github/workflows/lux-ci.yml`) runs:

```yaml
steps:
  1. mix format --check-formatted   # Code style
  2. mix credo                       # Static analysis
  3. mix dialyzer --format github    # Type checking
  4. mix test.unit                   # Unit tests
  5. mix python.test                 # Python tests
  6. mix coveralls.github            # Coverage
```

### Test Environment Configuration

```bash
# test.envrc
export MIX_ENV=test
export LUX_LLM_CHEAPEST="gpt-4o-mini"
export LUX_LLM_DEFAULT="gpt-4o-mini"
export LUX_LOG_LEVEL="warn"

# test.override.envrc (gitignored — for integration keys)
export INTEGRATION_OPENAI_API_KEY="sk-..."
export ALCHEMY_API_KEY="..."
```

## Best Practices

1. **Use the right test case**: `UnitCase` for isolated tests, `IntegrationCase` for external services
2. **Mock external dependencies**: Use Bypass for HTTP, Mox for behaviour-based mocking
3. **Test error paths**: Cover rate limiting, timeouts, malformed responses, and auth failures
4. **Keep tests fast**: Use `async: true` whenever possible; integration tests use `async: false`
5. **Test beam branches**: Ensure every branch condition in `branch do...end` blocks has a test
6. **Validate schemas in tests**: Test that lenses/prisms reject invalid inputs per their schema
7. **Clean up state**: For tests that create agents/hubs, ensure proper teardown
8. **Pin dependencies**: Use exact versions in `mix.lock` and `poetry.lock` for reproducible tests
