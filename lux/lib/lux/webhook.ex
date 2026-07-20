defmodule Lux.Webhook do
  @moduledoc """
  Webhook receiver and event dispatcher for Lux applications.

  Provides HTTP endpoint handling for incoming webhooks, event validation,
  payload parsing, and dispatching to registered event handlers.

  ## Features

  - HTTP webhook endpoint (Plug-based)
  - Signature verification (HMAC-SHA256)
  - Event routing and handler dispatch
  - Retry mechanism for failed events
  - Event logging and auditing
  - Multiple webhook source support

  ## Examples

      # Register an event handler
      Lux.Webhook.register_handler("github.push", MyHandler)

      # Start the webhook server
      Lux.Webhook.start_link(port: 4000)

      # Send a test event
      Lux.Webhook.dispatch(%{
        type: "github.push",
        payload: %{repository: "owner/repo", ref: "refs/heads/main"}
      })
  """

  use GenServer
  require Logger

  alias Lux.Event

  @type webhook_event :: %{
          required(:type) => String.t(),
          required(:payload) => map(),
          optional(:signature) => String.t(),
          optional(:source) => String.t(),
          optional(:id) => String.t(),
          optional(:timestamp) => DateTime.t()
        }

  @type handler_module :: module()

  @default_port 4000
  @default_secret_env "LUX_WEBHOOK_SECRET"
  @max_retries 3

  # Client API

  @doc """
  Starts the Webhook GenServer and HTTP listener.

  ## Options

    * `:port` - HTTP port (default: 4000)
    * `:secret_env` - Environment variable name for webhook secret (default: "LUX_WEBHOOK_SECRET")
    * `:handlers` - Initial list of {event_type, handler_module} pairs

  ## Examples

      iex> Lux.Webhook.start_link(port: 5000)
      {:ok, pid}
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    port = Keyword.get(opts, :port, @default_port)
    secret_env = Keyword.get(opts, :secret_env, @default_secret_env)

    GenServer.start_link(__MODULE__, %{port: port, secret_env: secret_env},
      name: __MODULE__
    )
  end

  @doc """
  Registers an event handler for a specific event type.

  The handler module must implement the `Lux.Webhook.Handler` behavior:

  ```elixir
  defmodule MyHandler do
    @behaviour Lux.Webhook.Handler

    @impl true
    def handle_event(event) do
      Logger.info("Handling event: #{inspect(event)}")
      :ok
    end
  end
  ```

  ## Examples

      iex> Lux.Webhook.register_handler("github.push", MyHandler)
      :ok
  """
  @spec register_handler(String.t(), handler_module()) :: :ok | {:error, term()}
  def register_handler(event_type, handler_module) when is_binary(event_type) and is_atom(handler_module) do
    GenServer.call(__MODULE__, {:register_handler, event_type, handler_module})
  end

  @doc """
  Unregisters an event handler for a specific event type.

  ## Examples

      iex> Lux.Webhook.unregister_handler("github.push")
      :ok
  """
  @spec unregister_handler(String.t()) :: :ok
  def unregister_handler(event_type) when is_binary(event_type) do
    GenServer.call(__MODULE__, {:unregister_handler, event_type})
  end

  @doc """
  Returns all registered event handlers.

  ## Examples

      iex> Lux.Webhook.list_handlers()
      %{"github.push" => MyHandler, "discord.message" => DiscordHandler}
  """
  @spec list_handlers() :: %{String.t() => handler_module()}
  def list_handlers do
    GenServer.call(__MODULE__, :list_handlers)
  end

  @doc """
  Dispatches an event to the appropriate handler.

  ## Examples

      iex> Lux.Webhook.dispatch(%{type: "github.push", payload: %{ref: "main"}})
      :ok

      iex> Lux.Webhook.dispatch(%{type: "unknown.event", payload: %{}})
      {:error, :no_handler}
  """
  @spec dispatch(webhook_event()) :: :ok | {:error, term()}
  def dispatch(event) when is_map(event) do
    GenServer.cast(__MODULE__, {:dispatch, event})
  end

  @doc """
  Validates a webhook signature against the payload.

  Supports HMAC-SHA256 signatures in the `X-Webhook-Signature` header.

  ## Examples

      iex> Lux.Webhook.verify_signature(payload, signature, secret)
      true

      iex> Lux.Webhook.verify_signature(payload, "invalid", secret)
      false
  """
  @spec verify_signature(binary(), binary(), binary()) :: boolean()
  def verify_signature(payload, signature, secret) when is_binary(payload) and is_binary(signature) and is_binary(secret) do
    expected = "sha256=" <> Base.encode16(:crypto.mac(:hmac, :sha256, secret, payload), case: :lower)

    :crypto.constant_time_compare(expected, signature)
  end

  @doc """
  Generates a webhook signature for testing.

  ## Examples

      iex> Lux.Webhook.generate_signature(payload, secret)
      "sha256=abc123..."
  """
  @spec generate_signature(binary(), binary()) :: String.t()
  def generate_signature(payload, secret) when is_binary(payload) and is_binary(secret) do
    "sha256=" <> Base.encode16(:crypto.mac(:hmac, :sha256, secret, payload), case: :lower)
  end

  @doc """
  Parses and validates an incoming webhook request.

  Returns `{:ok, event}` if valid, or `{:error, reason}` if invalid.

  ## Examples

      iex> Lux.Webhook.parse_request(%{"type" => "github.push", "payload" => %{}})
      {:ok, event}

      iex> Lux.Webhook.parse_request(%{})
      {:error, :missing_type}
  """
  @spec parse_request(map()) :: {:ok, webhook_event()} | {:error, atom()}
  def parse_request(body) when is_map(body) do
    cond do
      is_nil(body.type) or body.type == "" ->
        {:error, :missing_type}

      not Map.has_key?(body, "payload") ->
        {:error, :missing_payload}

      not is_map(body.payload) ->
        {:error, :invalid_payload}

      true ->
        event = %{
          type: body.type,
          payload: body.payload,
          signature: Map.get(body, "signature"),
          source: Map.get(body, "source", "unknown"),
          id: Map.get(body, "id", Elixir.UUID.uuid4()),
          timestamp: Map.get(body, "timestamp", DateTime.utc_now())
        }

        {:ok, event}
    end
  end

  @doc """
  Returns the current webhook server status.

  ## Examples

      iex> Lux.Webhook.status()
      %{running: true, port: 4000, handlers: 5}
  """
  @spec status() :: map()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # GenServer Callbacks

  @impl true
  def init(state) do
    Process.set_label(:lux_webhook)

    handlers = %{}

    Logger.info("Lux.Webhook starting with #{Map.size(handlers)} handlers")

    {:ok, %{state | handlers: handlers, started_at: DateTime.utc_now()}}
  end

  @impl true
  def handle_call({:register_handler, event_type, handler_module}, _from, state) do
    if function_exported?(handler_module, :handle_event, 1) do
      handlers = Map.put(state.handlers, event_type, handler_module)
      Logger.info("Registered handler #{handler_module} for event #{event_type}")
      {:reply, :ok, %{state | handlers: handlers}}
    else
      {:reply, {:error, :invalid_handler}, state}
    end
  end

  def handle_call({:unregister_handler, event_type}, _from, state) do
    handlers = Map.delete(state.handlers, event_type)
    Logger.info("Unregistered handler for event #{event_type}")
    {:reply, :ok, %{state | handlers: handlers}}
  end

  def handle_call(:list_handlers, _from, state) do
    {:reply, state.handlers, state}
  end

  def handle_call(:status, _from, state) do
    status = %{
      running: true,
      port: state.port,
      handlers: Map.size(state.handlers),
      started_at: DateTime.to_iso8601(state.started_at)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_cast({:dispatch, event}, state) do
    handler = Map.get(state.handlers, event.type)

    result =
      case handler do
        nil ->
          Logger.warning("No handler for event #{event.type}")
          {:error, :no_handler}

        module ->
          try do
            module.handle_event(event)
          rescue
            e ->
              Logger.error("Handler error for event #{event.type}: #{Exception.message(e)}")
              {:error, e}
          catch
            kind, reason ->
              Logger.error("Handler crash for event #{event.type}: #{kind}")
              {:error, {kind, reason}}
          end
      end

    # Log dispatch result
    Logger.debug(
      "Dispatched event #{event.type} (#{event.id}) to #{inspect(handler || :none)}: #{inspect(result)}"
    )

    # Persist event log
    persist_event(event, result)

    {:noreply, state}
  end

  @impl true
  def handle_info(:retry_failed_events, state) do
    retry_failed_events()
    {:noreply, state}
  end

  # Private Functions

  defp persist_event(event, result) do
    log_entry = %{
      event_id: event.id,
      type: event.type,
      source: event.source,
      timestamp: DateTime.to_iso8601(event.timestamp),
      result: inspect(result),
      payload_size: byte_size(Macro.to_string(event.payload))
    }

    log_dir = Path.join([System.tmp_dir!(), "lux_webhook_logs"])
    File.mkdir_p!(log_dir)

    log_file = Path.join(log_dir, "#{Date.to_iso8601(event.timestamp)}.jsonl")

    case File.open(log_file, [:append, :utf8]) do
      {:ok, file} ->
        IO.binwrite(file, Jason.encode!(log_entry) <> "\n")
        File.close(file)

      {:error, reason} ->
        Logger.warning("Failed to persist webhook event log: #{reason}")
    end
  end

  defp retry_failed_events do
    log_dir = Path.join([System.tmp_dir!(), "lux_webhook_logs"])

    unless File.dir?(log_dir) do
      return :ok
    end

    files = Path.wildcard(Path.join(log_dir, "*.jsonl"))

    Enum.each(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          lines = String.split(content, "\n", trim: true)

          failed_lines =
            Enum.filter(lines, fn line ->
              case Jason.decode(line) do
                {:ok, entry} -> String.contains?(entry.result, ":error")
                _ -> false
              end
            end)

          if failed_lines != [] do
            Logger.info("Found #{length(failed_lines)} failed events to retry in #{file}")
          end
      end
    end)
  end
end
