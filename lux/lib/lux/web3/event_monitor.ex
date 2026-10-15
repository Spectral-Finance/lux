defmodule Lux.Web3.EventMonitor do
  @moduledoc """
  Smart Contract Event Monitoring System for tracking, filtering, decoding,
  persisting, replaying, and dispatching webhook notifications for contract
  events across multiple EVM chains.
  """

  alias Lux.UUID
  alias Lux.Web3.EventMonitor.Decoder
  alias Lux.Web3.EventMonitor.Decoder.DecodedEvent
  alias Lux.Web3.EventMonitor.Filter
  alias Lux.Web3.EventMonitor.Store
  alias Lux.Web3.EventMonitor.Webhook

  @sub_table :lux_web3_event_subscriptions

  @default_endpoints %{
    ethereum: "https://eth.llamarpc.com",
    polygon: "https://polygon-rpc.com",
    bsc: "https://bsc-dataseed.binance.org",
    arbitrum: "https://arb1.arbitrum.io/rpc",
    optimism: "https://mainnet.optimism.io",
    base: "https://mainnet.base.org",
    avalanche: "https://api.avax.network/ext/bc/C/rpc"
  }

  defmodule Subscription do
    @moduledoc """
    Represents an active or paused smart contract event subscription.
    """

    alias Lux.Web3.EventMonitor.Filter

    @type status :: :active | :paused

    @type t :: %__MODULE__{
            id: String.t(),
            name: String.t(),
            chain: atom(),
            filter: Filter.t(),
            abis: [map()],
            webhook_url: String.t() | nil,
            webhook_secret: String.t() | nil,
            subscriber_pid: pid() | nil,
            callback: (map() -> any()) | nil,
            status: status(),
            matched_count: non_neg_integer(),
            created_at: DateTime.t()
          }

    defstruct id: nil,
              name: "Contract Subscription",
              chain: :ethereum,
              filter: %Filter{},
              abis: [],
              webhook_url: nil,
              webhook_secret: nil,
              subscriber_pid: nil,
              callback: nil,
              status: :active,
              matched_count: 0,
              created_at: nil
  end

  @doc """
  Initializes ETS tables for subscriptions, ABI registry, event persistence, and webhooks.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    Decoder.ensure_started()
    Store.ensure_started()
    Webhook.ensure_started()
    ensure_sub_table()
    :ok
  end

  @doc """
  Resets all subscriptions, persisted events, checkpoints, webhooks, and custom ABIs.
  """
  @spec reset!() :: :ok
  def reset! do
    ensure_started()
    Decoder.reset!()
    Store.reset!()
    Webhook.reset!()
    :ets.delete_all_objects(@sub_table)
    :ok
  end

  @doc """
  Creates and registers a new smart contract event subscription.
  """
  @spec subscribe(map() | keyword()) :: {:ok, Subscription.t()}
  def subscribe(opts) when is_map(opts) or is_list(opts) do
    ensure_started()
    params = Map.new(opts)
    chain = Map.get(params, :chain, :ethereum)

    filter =
      params
      |> Map.get(:filter, %{
        chains: [chain],
        contracts: Map.get(params, :contracts),
        event_names: Map.get(params, :event_names),
        topics: Map.get(params, :topics),
        param_patterns: Map.get(params, :param_patterns, %{})
      })
      |> Filter.new()

    sub = %Subscription{
      id: Map.get(params, :id) || UUID.generate(),
      name: Map.get(params, :name, "Contract Subscription"),
      chain: chain,
      filter: filter,
      abis: Map.get(params, :abis, []),
      webhook_url: Map.get(params, :webhook_url),
      webhook_secret: Map.get(params, :webhook_secret),
      subscriber_pid: Map.get(params, :subscriber_pid),
      callback: Map.get(params, :callback),
      status: :active,
      matched_count: 0,
      created_at: DateTime.utc_now()
    }

    :ets.insert(@sub_table, {sub.id, sub})
    {:ok, sub}
  end

  @doc """
  Removes a subscription by ID.
  """
  @spec unsubscribe(String.t()) :: :ok
  def unsubscribe(subscription_id) when is_binary(subscription_id) do
    ensure_started()
    :ets.delete(@sub_table, subscription_id)
    :ok
  end

  @doc """
  Pauses an active subscription.
  """
  @spec pause_subscription(String.t()) :: {:ok, Subscription.t()} | {:error, :not_found}
  def pause_subscription(subscription_id) do
    update_subscription(subscription_id, &%{&1 | status: :paused})
  end

  @doc """
  Resumes a paused subscription.
  """
  @spec resume_subscription(String.t()) :: {:ok, Subscription.t()} | {:error, :not_found}
  def resume_subscription(subscription_id) do
    update_subscription(subscription_id, &%{&1 | status: :active})
  end

  @doc """
  Fetches a subscription by ID.
  """
  @spec get_subscription(String.t()) :: {:ok, Subscription.t()} | {:error, :not_found}
  def get_subscription(subscription_id) when is_binary(subscription_id) do
    ensure_started()

    case :ets.lookup(@sub_table, subscription_id) do
      [{^subscription_id, sub}] -> {:ok, sub}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all registered subscriptions, optionally filtered by `:status` or `:chain`.
  """
  @spec list_subscriptions(keyword()) :: [Subscription.t()]
  def list_subscriptions(opts \\ []) do
    ensure_started()
    status_filter = Keyword.get(opts, :status)
    chain_filter = Keyword.get(opts, :chain)

    @sub_table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, sub} -> sub end)
    |> Enum.filter(fn sub ->
      (is_nil(status_filter) or sub.status == status_filter) and
        (is_nil(chain_filter) or sub.chain == chain_filter)
    end)
  end

  @doc """
  Polls new logs for a specific subscription via `eth_getLogs`, decodes and filters
  matching events, persists them, updates checkpoints, and dispatches notifications.
  """
  @spec poll_subscription(String.t(), keyword()) :: {:ok, [DecodedEvent.t()]} | {:error, term()}
  def poll_subscription(subscription_id, opts \\ []) do
    with {:ok, %Subscription{status: :active} = sub} <- get_subscription(subscription_id) do
      from_block =
        Keyword.get(opts, :from_block) ||
          case Store.get_checkpoint(sub.id, sub.chain) do
            nil -> "latest"
            last -> last + 1
          end

      to_block = Keyword.get(opts, :to_block, "latest")
      rpc_filter = Filter.to_rpc_filter(sub.filter, from_block, to_block)

      with {:ok, raw_logs} when is_list(raw_logs) <-
             rpc_get_logs(sub.chain, rpc_filter, opts) do
        events = process_logs_for_subscription(sub, raw_logs, opts)
        {:ok, events}
      end
    else
      {:ok, %Subscription{status: :paused}} -> {:ok, []}
      error -> error
    end
  end

  @doc """
  Syncs historical events for a subscription across `from_block..to_block` using
  chunked RPC batch queries (`:chunk_size`, default `2_000` blocks).
  """
  @spec sync_historical(String.t(), non_neg_integer(), non_neg_integer(), keyword()) ::
          {:ok, [DecodedEvent.t()]} | {:error, term()}
  def sync_historical(subscription_id, from_block, to_block, opts \\ [])
      when is_integer(from_block) and is_integer(to_block) and from_block <= to_block do
    chunk_size = Keyword.get(opts, :chunk_size, 2_000)

    with {:ok, %Subscription{} = sub} <- get_subscription(subscription_id) do
      ranges = chunk_block_range(from_block, to_block, chunk_size)

      events =
        Enum.flat_map(ranges, fn {chunk_start, chunk_end} ->
          rpc_filter = Filter.to_rpc_filter(sub.filter, chunk_start, chunk_end)

          case rpc_get_logs(sub.chain, rpc_filter, opts) do
            {:ok, raw_logs} when is_list(raw_logs) ->
              matched = process_logs_for_subscription(sub, raw_logs, opts)
              Store.put_checkpoint(sub.id, sub.chain, chunk_end)
              matched

            _ ->
              []
          end
        end)

      {:ok, events}
    end
  end

  @doc """
  Ingests raw logs directly for a chain and evaluates them against all active
  subscriptions on that chain.
  """
  @spec ingest_raw_logs(atom(), [map()], keyword()) :: {:ok, [DecodedEvent.t()]}
  def ingest_raw_logs(chain, raw_logs, opts \\ []) when is_atom(chain) and is_list(raw_logs) do
    ensure_started()
    subs = list_subscriptions(status: :active, chain: chain)

    matched =
      subs
      |> Enum.flat_map(&process_logs_for_subscription(&1, raw_logs, opts))
      |> Enum.uniq_by(& &1.id)

    {:ok, matched}
  end

  @doc """
  Returns a comprehensive monitoring dashboard snapshot containing subscription counts,
  persisted event breakdowns by chain and event name, checkpoint positions, and webhook
  delivery metrics.
  """
  @spec dashboard_snapshot() :: map()
  def dashboard_snapshot do
    ensure_started()
    subs = list_subscriptions()
    events = Store.list_events()
    deliveries = Webhook.list_deliveries()

    events_by_chain =
      events
      |> Enum.group_by(& &1.chain)
      |> Map.new(fn {chain, list} -> {chain, length(list)} end)

    events_by_name =
      events
      |> Enum.group_by(& &1.event_name)
      |> Map.new(fn {name, list} -> {name, length(list)} end)

    checkpoints =
      Map.new(subs, fn sub ->
        {sub.id, Store.get_checkpoint(sub.id, sub.chain)}
      end)

    %{
      subscriptions: %{
        total: length(subs),
        active: Enum.count(subs, &(&1.status == :active)),
        paused: Enum.count(subs, &(&1.status == :paused))
      },
      events: %{
        total: length(events),
        by_chain: events_by_chain,
        by_name: events_by_name
      },
      webhooks: %{
        total_deliveries: length(deliveries),
        delivered: Enum.count(deliveries, &(&1.status == :delivered)),
        failed: Enum.count(deliveries, &(&1.status == :failed))
      },
      checkpoints: checkpoints
    }
  end

  defdelegate register_abi(abi), to: Decoder
  defdelegate list_events(opts \\ %{}), to: Store
  defdelegate replay(filter_opts, consumer), to: Store

  defp process_logs_for_subscription(%Subscription{} = sub, raw_logs, opts) do
    matched =
      raw_logs
      |> Enum.map(&Decoder.decode_log(sub.chain, &1, sub.abis))
      |> Enum.filter(&Filter.matches?(&1, sub.filter))

    new_events =
      Enum.flat_map(matched, fn event ->
        case Store.save_event(event, sub.id) do
          {:new, saved} ->
            dispatch_notifications(sub, saved, opts)
            Store.put_checkpoint(sub.id, sub.chain, saved.block_number)
            [saved]

          {:duplicate, _existing} ->
            []
        end
      end)

    if new_events != [] do
      update_subscription(sub.id, fn current ->
        %{current | matched_count: current.matched_count + length(new_events)}
      end)
    end

    new_events
  end

  defp dispatch_notifications(%Subscription{} = sub, %DecodedEvent{} = event, opts) do
    if is_pid(sub.subscriber_pid) and Process.alive?(sub.subscriber_pid) do
      send(sub.subscriber_pid, {:contract_event, sub.id, event})
    end

    if is_function(sub.callback, 1) do
      sub.callback.(event)
    end

    if is_binary(sub.webhook_url) do
      webhook_opts =
        opts
        |> Keyword.take([:retries, :req_options])
        |> Keyword.put(:secret, sub.webhook_secret)

      _ = Webhook.deliver(sub.id, sub.webhook_url, event, webhook_opts)
    end

    :ok
  end

  defp rpc_get_logs(chain, rpc_filter, opts) do
    default_url = Map.get(@default_endpoints, chain, "https://eth.llamarpc.com")
    url = Keyword.get(opts, :rpc_url, default_url)

    payload = %{
      "jsonrpc" => "2.0",
      "id" => System.unique_integer([:positive]),
      "method" => "eth_getLogs",
      "params" => [rpc_filter]
    }

    req_opts =
      [
        url: url,
        json: payload,
        headers: [{"Content-Type", "application/json"}]
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> Keyword.merge(Keyword.get(opts, :req_options, []))

    case Req.post(Req.new(req_opts)) do
      {:ok, %{status: 200, body: %{"result" => logs}}} when is_list(logs) ->
        {:ok, logs}

      {:ok, %{status: 200, body: %{"error" => err}}} ->
        {:error, {:rpc_error, err}}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp chunk_block_range(from_block, to_block, chunk_size) do
    Stream.unfold(from_block, fn current ->
      if current > to_block do
        nil
      else
        chunk_end = min(current + chunk_size - 1, to_block)
        {{current, chunk_end}, chunk_end + 1}
      end
    end)
    |> Enum.to_list()
  end

  defp update_subscription(id, fun) do
    case get_subscription(id) do
      {:ok, sub} ->
        updated = fun.(sub)
        :ets.insert(@sub_table, {id, updated})
        {:ok, updated}

      error ->
        error
    end
  end

  defp ensure_sub_table do
    case :ets.whereis(@sub_table) do
      :undefined ->
        try do
          :ets.new(@sub_table, [:named_table, :public, :set, read_concurrency: true])
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end
end
