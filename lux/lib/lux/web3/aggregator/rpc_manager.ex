defmodule Lux.Web3.Aggregator.RPCManager do
  @moduledoc """
  Multi-chain EVM JSON-RPC endpoint manager with per-chain rate limiting,
  endpoint failover, error tracking, and retry handling.
  """

  @chain_table :lux_multichain_rpc_chains
  @rate_table :lux_multichain_rpc_rates

  defmodule Network do
    @moduledoc """
    Configuration and runtime state for a monitored EVM blockchain network.
    """

    @type t :: %__MODULE__{
            id: atom(),
            chain_id: pos_integer(),
            name: String.t(),
            native_symbol: String.t(),
            endpoints: [String.t()],
            rate_limit_per_window: pos_integer(),
            window_ms: pos_integer(),
            block_time_ms: pos_integer(),
            failure_count: non_neg_integer()
          }

    defstruct id: :ethereum,
              chain_id: 1,
              name: "Ethereum Mainnet",
              native_symbol: "ETH",
              endpoints: ["https://eth.llamarpc.com"],
              rate_limit_per_window: 50,
              window_ms: 1_000,
              block_time_ms: 12_000,
              failure_count: 0
  end

  @doc """
  Initializes ETS tables and seeds default EVM networks.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    ensure_table(@chain_table)
    ensure_table(@rate_table)

    if :ets.info(@chain_table, :size) == 0 do
      seed_defaults()
    end

    :ok
  end

  @doc """
  Resets all network configurations and rate-limit counters to defaults.
  """
  @spec reset!() :: :ok
  def reset! do
    ensure_started()
    :ets.delete_all_objects(@chain_table)
    :ets.delete_all_objects(@rate_table)
    seed_defaults()
  end

  @doc """
  Registers or updates an EVM network configuration.
  """
  @spec register_network(Network.t() | map()) :: {:ok, Network.t()}
  def register_network(%Network{} = net) do
    ensure_started()
    :ets.insert(@chain_table, {net.id, net})
    {:ok, net}
  end

  def register_network(attrs) when is_map(attrs) do
    net = struct(Network, attrs)
    register_network(net)
  end

  @doc """
  Fetches a network configuration by atom identifier or numeric `chain_id`.
  """
  @spec get_network(atom() | pos_integer()) :: {:ok, Network.t()} | {:error, :unknown_chain}
  def get_network(chain_id) when is_atom(chain_id) do
    ensure_started()

    case :ets.lookup(@chain_table, chain_id) do
      [{^chain_id, net}] -> {:ok, net}
      [] -> {:error, :unknown_chain}
    end
  end

  def get_network(chain_id) when is_integer(chain_id) do
    ensure_started()

    @chain_table
    |> :ets.tab2list()
    |> Enum.find_value({:error, :unknown_chain}, fn {_id, net} ->
      if net.chain_id == chain_id, do: {:ok, net}
    end)
  end

  @doc """
  Lists all registered EVM networks ordered by `chain_id`.
  """
  @spec list_networks() :: [Network.t()]
  def list_networks do
    ensure_started()

    @chain_table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, net} -> net end)
    |> Enum.sort_by(& &1.chain_id)
  end

  @doc """
  Executes a JSON-RPC request on the given chain with rate limiting and
  automatic failover across configured RPC endpoints.
  """
  @spec call(atom() | pos_integer(), String.t(), list(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def call(chain_ref, method, params \\ [], opts \\ []) do
    with {:ok, net} <- get_network(chain_ref),
         :ok <- check_rate_limit(net) do
      call_endpoints(net, net.endpoints, method, params, opts, nil)
    end
  end

  defp call_endpoints(net, [], _method, _params, _opts, last_error) do
    increment_failure(net.id)
    {:error, last_error || :all_endpoints_failed}
  end

  defp call_endpoints(net, [endpoint | rest], method, params, opts, _last_error) do
    body = %{
      "jsonrpc" => "2.0",
      "id" => Keyword.get(opts, :id, System.unique_integer([:positive])),
      "method" => method,
      "params" => params
    }

    req_opts =
      [
        url: endpoint,
        json: body,
        headers: [{"Content-Type", "application/json"}, {"x-lux-chain", Atom.to_string(net.id)}]
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> Keyword.merge(Keyword.get(opts, :req_options, []))

    case Req.post(Req.new(req_opts)) do
      {:ok, %{status: 200, body: %{"result" => result}}} ->
        reset_failure(net.id)
        {:ok, result}

      {:ok, %{status: 200, body: %{"error" => rpc_error}}} ->
        call_endpoints(net, rest, method, params, opts, {:rpc_error, rpc_error})

      {:ok, %{status: status, body: resp_body}} ->
        call_endpoints(net, rest, method, params, opts, {:http_error, status, resp_body})

      {:error, reason} ->
        call_endpoints(net, rest, method, params, opts, reason)
    end
  end

  defp check_rate_limit(%Network{
         id: id,
         rate_limit_per_window: limit,
         window_ms: window_ms
       }) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@rate_table, id) do
      [{^id, count, window_start}] when now - window_start < window_ms ->
        if count >= limit do
          {:error, :rate_limited}
        else
          :ets.insert(@rate_table, {id, count + 1, window_start})
          :ok
        end

      _ ->
        :ets.insert(@rate_table, {id, 1, now})
        :ok
    end
  end

  defp increment_failure(id) do
    case :ets.lookup(@chain_table, id) do
      [{^id, net}] ->
        :ets.insert(@chain_table, {id, %{net | failure_count: net.failure_count + 1}})

      [] ->
        :ok
    end
  end

  defp reset_failure(id) do
    case :ets.lookup(@chain_table, id) do
      [{^id, net}] ->
        :ets.insert(@chain_table, {id, %{net | failure_count: 0}})

      [] ->
        :ok
    end
  end

  defp seed_defaults do
    Enum.each(default_networks(), fn net ->
      :ets.insert(@chain_table, {net.id, net})
    end)

    :ok
  end

  defp default_networks do
    [
      %Network{
        id: :ethereum,
        chain_id: 1,
        name: "Ethereum Mainnet",
        native_symbol: "ETH",
        endpoints: ["https://eth.llamarpc.com", "https://rpc.ankr.com/eth"],
        block_time_ms: 12_000
      },
      %Network{
        id: :optimism,
        chain_id: 10,
        name: "Optimism",
        native_symbol: "ETH",
        endpoints: ["https://mainnet.optimism.io"],
        block_time_ms: 2_000
      },
      %Network{
        id: :bsc,
        chain_id: 56,
        name: "BNB Smart Chain",
        native_symbol: "BNB",
        endpoints: ["https://bsc-dataseed.binance.org"],
        block_time_ms: 3_000
      },
      %Network{
        id: :polygon,
        chain_id: 137,
        name: "Polygon PoS",
        native_symbol: "POL",
        endpoints: ["https://polygon-rpc.com"],
        block_time_ms: 2_000
      },
      %Network{
        id: :base,
        chain_id: 8453,
        name: "Base",
        native_symbol: "ETH",
        endpoints: ["https://mainnet.base.org"],
        block_time_ms: 2_000
      },
      %Network{
        id: :arbitrum,
        chain_id: 42_161,
        name: "Arbitrum One",
        native_symbol: "ETH",
        endpoints: ["https://arb1.arbitrum.io/rpc"],
        block_time_ms: 250
      },
      %Network{
        id: :avalanche,
        chain_id: 43_114,
        name: "Avalanche C-Chain",
        native_symbol: "AVAX",
        endpoints: ["https://api.avax.network/ext/bc/C/rpc"],
        block_time_ms: 2_000
      }
    ]
  end

  defp ensure_table(name) do
    case :ets.whereis(name) do
      :undefined ->
        try do
          :ets.new(name, [:named_table, :public, :set, read_concurrency: true])
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end
end
