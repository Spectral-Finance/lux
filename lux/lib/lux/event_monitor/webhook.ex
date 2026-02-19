defmodule Lux.EventMonitor.Webhook do
  @moduledoc """
  Manages webhook notifications for smart contract events.

  Webhooks allow external systems to receive real-time notifications when
  events matching their criteria are detected. Each webhook registration
  includes a target URL, event filter criteria, and optional configuration
  for retry behavior and authentication.

  ## Webhook Registration

      webhook = %{
        id: "wh_123",
        url: "https://api.example.com/events",
        filter: %{event_name: "Transfer", address: "0x..."},
        headers: %{"Authorization" => "Bearer token"},
        max_retries: 3,
        retry_delay_ms: 1000,
        active: true
      }

  ## Notification Payload

  When an event matches a webhook's filter, the following JSON payload is sent:

      {
        "event_id": "0xtxhash:0",
        "event_name": "Transfer",
        "address": "0x...",
        "block_number": 12345,
        "chain_id": 1,
        "transaction_hash": "0x...",
        "decoded_params": {...},
        "timestamp": 1234567890,
        "webhook_id": "wh_123"
      }
  """

  use GenServer

  alias Lux.EventMonitor.EventLog
  alias Lux.EventMonitor.Filter

  require Logger

  @type webhook_config :: %{
          id: String.t(),
          url: String.t(),
          filter: Filter.filter_spec(),
          headers: %{String.t() => String.t()},
          max_retries: non_neg_integer(),
          retry_delay_ms: non_neg_integer(),
          active: boolean(),
          secret: String.t() | nil
        }

  defstruct [:table, :name, http_client: nil]

  # Client API

  @doc """
  Starts the webhook manager.

  ## Options

    * `:name` - Registered name for the GenServer (default: `__MODULE__`)
    * `:http_client` - Custom HTTP client module for testing (default: uses Req)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Registers a new webhook.

  ## Parameters

    * `server` - The webhook manager process
    * `config` - Webhook configuration map

  ## Returns

  `{:ok, webhook_id}` on success.
  """
  @spec register(GenServer.server(), map()) :: {:ok, String.t()}
  def register(server, config) do
    GenServer.call(server, {:register, config})
  end

  @doc """
  Unregisters a webhook by ID.
  """
  @spec unregister(GenServer.server(), String.t()) :: :ok | {:error, :not_found}
  def unregister(server, webhook_id) do
    GenServer.call(server, {:unregister, webhook_id})
  end

  @doc """
  Lists all registered webhooks.
  """
  @spec list(GenServer.server()) :: [webhook_config()]
  def list(server) do
    GenServer.call(server, :list)
  end

  @doc """
  Notifies all matching webhooks about an event.

  This function checks the event against all active webhook filters and
  sends HTTP POST requests to matching webhook URLs.
  """
  @spec notify(GenServer.server(), EventLog.t()) :: :ok
  def notify(server, %EventLog{} = event_log) do
    GenServer.cast(server, {:notify, event_log})
  end

  @doc """
  Notifies all matching webhooks about a batch of events.
  """
  @spec notify_batch(GenServer.server(), [EventLog.t()]) :: :ok
  def notify_batch(server, event_logs) when is_list(event_logs) do
    GenServer.cast(server, {:notify_batch, event_logs})
  end

  @doc """
  Activates or deactivates a webhook.
  """
  @spec set_active(GenServer.server(), String.t(), boolean()) :: :ok | {:error, :not_found}
  def set_active(server, webhook_id, active) do
    GenServer.call(server, {:set_active, webhook_id, active})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    http_client = Keyword.get(opts, :http_client)

    table = :ets.new(:"#{name}_webhooks", [:set, :protected])

    state = %__MODULE__{
      table: table,
      name: name,
      http_client: http_client
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:register, config}, _from, state) do
    webhook_id = Map.get(config, :id, generate_id())

    webhook = %{
      id: webhook_id,
      url: Map.fetch!(config, :url),
      filter: Map.get(config, :filter, %{}),
      headers: Map.get(config, :headers, %{}),
      max_retries: Map.get(config, :max_retries, 3),
      retry_delay_ms: Map.get(config, :retry_delay_ms, 1_000),
      active: Map.get(config, :active, true),
      secret: Map.get(config, :secret),
      created_at: System.system_time(:second)
    }

    :ets.insert(state.table, {webhook_id, webhook})
    {:reply, {:ok, webhook_id}, state}
  end

  def handle_call({:unregister, webhook_id}, _from, state) do
    case :ets.lookup(state.table, webhook_id) do
      [] -> {:reply, {:error, :not_found}, state}
      _ ->
        :ets.delete(state.table, webhook_id)
        {:reply, :ok, state}
    end
  end

  def handle_call(:list, _from, state) do
    webhooks =
      :ets.tab2list(state.table)
      |> Enum.map(fn {_id, webhook} -> webhook end)

    {:reply, webhooks, state}
  end

  def handle_call({:set_active, webhook_id, active}, _from, state) do
    case :ets.lookup(state.table, webhook_id) do
      [] ->
        {:reply, {:error, :not_found}, state}

      [{_id, webhook}] ->
        updated = %{webhook | active: active}
        :ets.insert(state.table, {webhook_id, updated})
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_cast({:notify, event_log}, state) do
    do_notify(state, event_log)
    {:noreply, state}
  end

  def handle_cast({:notify_batch, event_logs}, state) do
    Enum.each(event_logs, &do_notify(state, &1))
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    :ets.delete(state.table)
    :ok
  end

  # Internal implementation

  defp do_notify(state, %EventLog{} = event_log) do
    active_webhooks =
      :ets.tab2list(state.table)
      |> Enum.map(fn {_id, webhook} -> webhook end)
      |> Enum.filter(& &1.active)

    Enum.each(active_webhooks, fn webhook ->
      if Filter.matches?(event_log, webhook.filter) do
        send_webhook(state, webhook, event_log)
      end
    end)
  end

  defp send_webhook(state, webhook, event_log) do
    payload = build_payload(webhook, event_log)

    Task.start(fn ->
      deliver_with_retries(state, webhook, payload, 0)
    end)
  end

  defp deliver_with_retries(state, webhook, payload, attempt) do
    case do_http_post(state, webhook, payload) do
      {:ok, _} ->
        Logger.debug("Webhook #{webhook.id} delivered successfully")

      {:error, reason} ->
        if attempt < webhook.max_retries do
          Logger.warning("Webhook #{webhook.id} failed (attempt #{attempt + 1}): #{inspect(reason)}")
          Process.sleep(webhook.retry_delay_ms * (attempt + 1))
          deliver_with_retries(state, webhook, payload, attempt + 1)
        else
          Logger.error("Webhook #{webhook.id} failed after #{webhook.max_retries} retries: #{inspect(reason)}")
        end
    end
  end

  defp do_http_post(state, webhook, payload) do
    if state.http_client do
      # Use custom HTTP client (for testing)
      state.http_client.post(webhook.url, payload, webhook.headers)
    else
      headers =
        webhook.headers
        |> Enum.map(fn {k, v} -> {k, v} end)
        |> Kernel.++([{"content-type", "application/json"}])

      headers =
        if webhook.secret do
          signature = compute_signature(payload, webhook.secret)
          [{"x-webhook-signature", signature} | headers]
        else
          headers
        end

      case Req.post(webhook.url, json: payload, headers: headers) do
        {:ok, %{status: status}} when status in 200..299 -> {:ok, status}
        {:ok, resp} -> {:error, "HTTP #{resp.status}"}
        {:error, error} -> {:error, inspect(error)}
      end
    end
  end

  defp build_payload(webhook, %EventLog{} = event_log) do
    %{
      webhook_id: webhook.id,
      event_id: EventLog.unique_id(event_log),
      event_name: event_log.event_name,
      address: event_log.address,
      block_number: event_log.block_number,
      chain_id: event_log.chain_id,
      transaction_hash: event_log.transaction_hash,
      log_index: event_log.log_index,
      decoded_params: event_log.decoded_params || %{},
      data: event_log.data,
      topics: event_log.topics,
      timestamp: event_log.timestamp,
      removed: event_log.removed
    }
  end

  defp compute_signature(payload, secret) do
    json = Jason.encode!(payload)

    :crypto.mac(:hmac, :sha256, secret, json)
    |> Base.encode16(case: :lower)
  end

  defp generate_id do
    "wh_" <> (System.unique_integer([:positive]) |> Integer.to_string(36) |> String.downcase())
  end
end
