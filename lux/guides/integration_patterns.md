# Integration Patterns

This guide covers patterns and best practices for integrating Lux with external systems, APIs, and services. Use these patterns to build reliable, maintainable integrations.

## Lens Pattern: REST API Integration

The most common integration pattern is wrapping REST APIs as Lenses:

### Basic REST Lens

```elixir
defmodule MyApp.Lenses.GitHubIssuesLens do
  use Lux.Lens,
    name: "GitHub Issues API",
    description: "Fetches issues from a GitHub repository",
    url: "https://api.github.com/repos/:owner/:repo/issues",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        owner: %{type: :string, description: "Repository owner"},
        repo: %{type: :string, description: "Repository name"},
        state: %{type: :string, enum: ["open", "closed", "all"]},
        labels: %{type: :string, description: "Comma-separated label names"},
        per_page: %{type: :integer, minimum: 1, maximum: 100}
      },
      required: ["owner", "repo"]
    },
    auth: %{type: :api_key, key: fn -> System.get_env("GITHUB_TOKEN") end}

  def after_focus(body) when is_list(body) do
    issues = Enum.map(body, fn issue ->
      %{
        number: issue["number"],
        title: issue["title"],
        state: issue["state"],
        url: issue["html_url"],
        labels: Enum.map(issue["labels"], & &1["name"])
      }
    end)
    {:ok, issues}
  end

  def after_focus(%{"message" => message}) do
    {:error, "GitHub API error: #{message}"}
  end
end
```

### Paginated Lens

For APIs with pagination:

```elixir
defmodule MyApp.Lenses.PaginatedSearchLens do
  use Lux.Lens,
    name: "Paginated Search",
    url: "https://api.example.com/v1/search",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        query: %{type: :string},
        page: %{type: :integer, default: 1},
        page_size: %{type: :integer, default: 50}
      },
      required: ["query"]
    }

  def after_focus(%{"items" => items, "total" => total, "page" => page, "pages" => pages}) do
    {:ok, %{
      items: items,
      pagination: %{
        current_page: page,
        total_pages: pages,
        total_items: total,
        has_more: page < pages
      }
    }}
  end
end
```

### Lens with Dynamic URL Construction

For APIs requiring complex URL construction:

```elixir
defmodule MyApp.Lenses.DynamicURLLens do
  use Lux.Lens,
    name: "Dynamic URL API",
    url: "",  # URL built in before_focus
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        resource_type: %{type: :string, enum: ["users", "orders", "products"]},
        id: %{type: :string}
      },
      required: ["resource_type", "id"]
    }

  def before_focus(params) do
    # Build URL dynamically
    Map.put(params, :_url, "https://api.example.com/v1/#{params.resource_type}/#{params.id}")
  end
end
```

## Prism Pattern: Data Transformation

Prisms are ideal for data processing pipelines that don't require HTTP calls:

### ETL Prism

```elixir
defmodule MyApp.Prisms.ETLTransformer do
  @behaviour Lux.Prism

  @impl true
  def handler(params, _ctx) do
    result =
      params.data
      |> extract_relevant_fields()
      |> transform_format()
      |> validate_output()

    {:ok, result}
  end

  defp extract_relevant_fields(data) do
    Map.take(data, [:id, :name, :value, :timestamp])
  end

  defp transform_format(data) do
    %{
      external_id: data.id,
      label: String.upcase(data.name),
      amount: Decimal.new(data.value),
      processed_at: DateTime.utc_now()
    }
  end

  defp validate_output(data) do
    if data.amount |> Decimal.positive?() do
      data
    else
      Map.put(data, :warning, "non_positive_amount")
    end
  end
end
```

### Multi-Step Prism Pipeline

Chain prisms together for complex transformations:

```elixir
defmodule MyApp.Beams.DataPipeline do
  use Lux.Beam,
    name: "Data Pipeline",
    input_schema: %{
      type: :object,
      properties: %{raw_data: %{type: :array}},
      required: ["raw_data"]
    }

  sequence do
    step(:validate, MyApp.Prisms.SchemaValidator, %{
      data: {:ref, "raw_data"},
      schema: :customer_record
    })

    step(:enrich, MyApp.Prisms.DataEnricher, %{
      records: {:ref, "validate.valid_records"},
      enrichment_source: :crm
    })

    step(:transform, MyApp.Prisms.ETLTransformer, %{
      data: {:ref, "enrich.enriched_records"}
    })

    step(:load, MyApp.Prisms.DatabaseLoader, %{
      records: {:ref, "transform"},
      target_table: :processed_customers
    })
  end
end
```

## Webhook Integration Pattern

Receiving external events via webhooks:

```elixir
defmodule MyApp.Webhooks.GitHubHandler do
  use Lux.Agent,
    name: "GitHub Webhook Handler",
    description: "Processes incoming GitHub webhook events"

  def handle_webhook(event_type, payload, signature) do
    with :ok <- verify_signature(payload, signature),
         {:ok, signal} <- convert_to_signal(event_type, payload) do
      # Dispatch as internal signal for other agents to process
      Lux.AgentHub.emit(signal)
      {:ok, :accepted}
    end
  end

  defp convert_to_signal("pull_request", payload) do
    signal = %Lux.Signal{
      schema_id: "github_pr_event_v1",
      content: %{
        action: payload["action"],
        pr_number: payload["number"],
        title: payload["pull_request"]["title"],
        author: payload["pull_request"]["user"]["login"],
        repo: payload["repository"]["full_name"]
      }
    }
    {:ok, signal}
  end

  defp convert_to_signal("issues", payload) do
    signal = %Lux.Signal{
      schema_id: "github_issue_event_v1",
      content: %{
        action: payload["action"],
        issue_number: payload["issue"]["number"],
        title: payload["issue"]["title"]
      }
    }
    {:ok, signal}
  end

  defp verify_signature(payload, signature) do
    secret = System.get_env("GITHUB_WEBHOOK_SECRET")
    expected = "sha256=" <> (:crypto.hmac(:sha256, secret, payload) |> Base.encode16(case: :lower))
    
    if Plug.Crypto.secure_compare(signature, expected) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end
end
```

## Database Integration Pattern

For agents needing persistent storage:

```elixir
defmodule MyApp.Prisms.DatabaseQuery do
  @behaviour Lux.Prism

  @impl true
  def handler(%{query: query, params: params}, _ctx) do
    result = MyApp.Repo.query(query, params)
    
    case result do
      {:ok, %{rows: rows, columns: columns}} ->
        formatted = format_rows(rows, columns)
        {:ok, formatted}

      {:error, error} ->
        {:error, "Database query failed: #{inspect(error)}"}
    end
  end

  defp format_rows(rows, columns) do
    Enum.map(rows, fn row ->
      columns
      |> Enum.zip(Tuple.to_list(row))
      |> Map.new()
    end)
  end
end
```

## Real-Time Streaming Pattern

For WebSocket or SSE integrations:

```elixir
defmodule MyApp.Lenses.StreamingDataLens do
  use Lux.Lens,
    name: "Real-Time Market Data",
    url: "wss://stream.example.com/v1/market",
    method: :websocket

  def after_focus({:websocket, socket}) do
    # Subscribe to channels
    WebSocket.send(socket, %{
      type: "subscribe",
      channels: ["trades.BTC-USD", "trades.ETH-USD"]
    })

    # Start a process to handle incoming messages
    Task.start_link(fn -> handle_messages(socket) end)

    {:ok, %{status: :subscribed, channels: ["BTC-USD", "ETH-USD"]}}
  end

  defp handle_messages(socket) do
    receive do
      {:websocket_frame, frame} ->
        data = Jason.decode!(frame)
        # Emit as signal for agents to consume
        Lux.AgentHub.broadcast(%Lux.Signal{
          schema_id: "market_data_v1",
          content: data
        })
        handle_messages(socket)

      {:websocket_closed, _reason} ->
        Logger.info("WebSocket connection closed")
    end
  end
end
```

## Error Handling Patterns

### Retry with Exponential Backoff

```elixir
defmodule MyApp.Prisms.RobustAPIClient do
  @behaviour Lux.Prism

  @max_retries 5
  @base_delay 1000

  @impl true
  def handler(params, _ctx) do
    attempt_request(params, 1)
  end

  defp attempt_request(params, attempt) when attempt <= @max_retries do
    case make_api_call(params) do
      {:ok, result} ->
        {:ok, result}

      {:error, :rate_limited} ->
        delay = @base_delay * :math.pow(2, attempt - 1) |> round()
        Logger.warning("Rate limited, retrying in #{delay}ms (attempt #{attempt}/#{@max_retries})")
        Process.sleep(delay)
        attempt_request(params, attempt + 1)

      {:error, :server_error} when attempt < @max_retries ->
        Logger.warning("Server error, retrying (attempt #{attempt}/#{@max_retries})")
        Process.sleep(@base_delay)
        attempt_request(params, attempt + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp attempt_request(_params, attempt) do
    {:error, "Max retries (#{@max_retries}) exceeded"}
  end
end
```

### Circuit Breaker Pattern

```elixir
defmodule MyApp.CircuitBreaker do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def init(opts) do
    state = %{
      failures: 0,
      threshold: Keyword.get(opts, :threshold, 5),
      reset_timeout: Keyword.get(opts, :reset_timeout, 30_000),
      state: :closed,
      last_failure: nil
    }
    {:ok, state}
  end

  def call(breaker, func) do
    GenServer.call(breaker, {:execute, func})
  end

  def handle_call({:execute, func}, _from, %{state: :open} = state) do
    if circuit_should_reset?(state) do
      {:reply, {:error, :circuit_open}, %{state | state: :half_open}}
    else
      {:reply, {:error, :circuit_open}, state}
    end
  end

  def handle_call({:execute, func}, _from, state) do
    case func.() do
      {:ok, result} ->
        {:reply, {:ok, result}, %{state | failures: 0, state: :closed}}

      {:error, _reason} ->
        new_failures = state.failures + 1
        new_state = if new_failures >= state.threshold, do: :open, else: state.state
        {:reply, {:error, :execution_failed},
         %{state | failures: new_failures, state: new_state, last_failure: DateTime.utc_now()}}
    end
  end

  defp circuit_should_reset?(state) do
    DateTime.diff(DateTime.utc_now(), state.last_failure, :millisecond) > state.reset_timeout
  end
end
```

## Testing Integrations

### Mock External APIs

```elixir
defmodule MyApp.Lenses.WeatherLensTest do
  use ExUnit.Case, async: true

  import Mock

  test "fetches weather data successfully" do
    with_mock Req, 
      request: fn _req ->
        {:ok, %{status: 200, body: %{"main" => %{"temp" => 22.5}, "weather" => [%{"description" => "clear sky"}]}}}
      end do
      
      result = MyApp.Lenses.WeatherLens.focus(%{q: "London", appid: "test_key"})
      
      assert {:ok, %{temperature: 22.5, description: "clear sky"}} = result
    end
  end

  test "handles API errors gracefully" do
    with_mock Req,
      request: fn _req ->
        {:ok, %{status: 401, body: %{"message" => "Invalid API key"}}}
      end do
      
      result = MyApp.Lenses.WeatherLens.focus(%{q: "London", appid: "bad_key"})
      
      assert {:error, _} = result
    end
  end
end
```

### Integration Test with Bypass

```elixir
defmodule MyApp.Lenses.APIIntegrationTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  test "handles successful API response", %{bypass: bypass} do
    Bypass.expect(bypass, "GET", "/api/v1/data", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"status": "ok", "data": [1, 2, 3]}))
    end)

    # Configure lens to use bypass URL for testing
    result = MyApp.Lenses.MyLens.focus(%{}, url_override: "http://localhost:#{bypass.port}/api/v1/data")
    
    assert {:ok, %{status: "ok", data: [1, 2, 3]}} = result
  end
end
```
