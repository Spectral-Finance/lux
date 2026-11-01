defmodule Lux.Web3.Multichain.RpcManager do
  @moduledoc """
  Multi-Chain RPC Management Engine with intelligent failover, health checks,
  and rate limiting for EVM networks (#74).

  Supported Networks:
  - Ethereum (Chain ID: 1)
  - BNB Smart Chain / BSC (Chain ID: 56)
  - Polygon PoS (Chain ID: 137)
  - Arbitrum One (Chain ID: 42161)
  - Optimism (Chain ID: 10)
  - Base (Chain ID: 8453)
  - Avalanche C-Chain (Chain ID: 43114)
  """

  use GenServer
  require Logger

  @default_chains %{
    ethereum: %{
      chain_id: 1,
      name: "Ethereum Mainnet",
      endpoints: [
        "https://eth.llamarpc.com",
        "https://cloudflare-eth.com",
        "https://rpc.ankr.com/eth"
      ]
    },
    bsc: %{
      chain_id: 56,
      name: "BNB Smart Chain",
      endpoints: [
        "https://binance.llamarpc.com",
        "https://bsc-dataseed.binance.org",
        "https://rpc.ankr.com/bsc"
      ]
    },
    polygon: %{
      chain_id: 137,
      name: "Polygon PoS",
      endpoints: [
        "https://polygon.llamarpc.com",
        "https://polygon-rpc.com",
        "https://rpc.ankr.com/polygon"
      ]
    },
    arbitrum: %{
      chain_id: 42161,
      name: "Arbitrum One",
      endpoints: [
        "https://arbitrum.llamarpc.com",
        "https://arb1.arbitrum.io/rpc",
        "https://rpc.ankr.com/arbitrum"
      ]
    },
    optimism: %{
      chain_id: 10,
      name: "OP Mainnet",
      endpoints: [
        "https://optimism.llamarpc.com",
        "https://mainnet.optimism.io",
        "https://rpc.ankr.com/optimism"
      ]
    },
    base: %{
      chain_id: 8453,
      name: "Base",
      endpoints: [
        "https://base.llamarpc.com",
        "https://mainnet.base.org",
        "https://rpc.ankr.com/base"
      ]
    },
    avalanche: %{
      chain_id: 43114,
      name: "Avalanche C-Chain",
      endpoints: [
        "https://api.avax.network/ext/bc/C/rpc",
        "https://avalanche.public-rpc.com",
        "https://rpc.ankr.com/avalanche"
      ]
    }
  }

  defstruct [
    :chains,
    :endpoint_states,
    :rate_limit_config
  ]

  # Client API

  @doc """
  Starts the RpcManager GenServer.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns list of all supported chain atoms.
  """
  @spec supported_chains() :: [atom()]
  def supported_chains, do: Map.keys(@default_chains)

  @doc """
  Retrieves chain configuration and metadata for a chain atom.
  """
  @spec get_chain_info(atom()) :: {:ok, map()} | {:error, :unsupported_chain}
  def get_chain_info(chain) when is_atom(chain) do
    case Map.fetch(@default_chains, chain) do
      {:ok, info} -> {:ok, info}
      :error -> {:error, :unsupported_chain}
    end
  end

  @doc """
  Retrieves chain ID for a given chain atom.
  """
  @spec get_chain_id(atom()) :: {:ok, non_neg_integer()} | {:error, :unsupported_chain}
  def get_chain_id(chain) when is_atom(chain) do
    case get_chain_info(chain) do
      {:ok, %{chain_id: id}} -> {:ok, id}
      error -> error
    end
  end

  @doc """
  Executes an RPC call with automatic failover to alternative healthy endpoints on error.
  """
  @spec rpc_call(GenServer.server(), atom(), String.t(), list(), keyword()) ::
          {:ok, term()} | {:error, term()}
  def rpc_call(server \\ __MODULE__, chain, method, params \\ [], opts \\ []) do
    GenServer.call(server, {:rpc_call, chain, method, params, opts}, 30_000)
  end

  @doc """
  Reports endpoint health statistics across all chains.
  """
  @spec get_health(GenServer.server()) :: map()
  def get_health(server \\ __MODULE__) do
    GenServer.call(server, :get_health)
  end

  @doc """
  Manually registers custom RPC endpoints for a chain.
  """
  @spec register_endpoints(GenServer.server(), atom(), [String.t()]) :: :ok | {:error, term()}
  def register_endpoints(server \\ __MODULE__, chain, endpoints)
      when is_atom(chain) and is_list(endpoints) do
    GenServer.call(server, {:register_endpoints, chain, endpoints})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    custom_chains = Keyword.get(opts, :chains, %{})
    chains = Map.merge(@default_chains, custom_chains)

    endpoint_states =
      for {chain, %{endpoints: eps}} <- chains,
          ep <- eps,
          into: %{} do
        {ep,
         %{
           chain: chain,
           healthy: true,
           consecutive_failures: 0,
           total_requests: 0,
           total_errors: 0,
           cooldown_until: 0,
           last_latency_ms: 0
         }}
      end

    rate_limit = Keyword.get(opts, :rate_limit_config, %{max_consecutive_failures: 3, cooldown_sec: 30})

    {:ok,
     %__MODULE__{
       chains: chains,
       endpoint_states: endpoint_states,
       rate_limit_config: rate_limit
     }}
  end

  @impl true
  def handle_call({:rpc_call, chain, method, params, opts}, _from, state) do
    case Map.get(state.chains, chain) do
      nil ->
        {:reply, {:error, {:unsupported_chain, chain}}, state}

      %{endpoints: eps} ->
        case select_healthy_endpoint(eps, state.endpoint_states) do
          nil ->
            {:reply, {:error, {:all_endpoints_exhausted, chain}}, state}

          endpoint ->
            mock_client = Keyword.get(opts, :mock_client)
            {result, new_states} = execute_rpc_with_failover(endpoint, eps, method, params, state, mock_client)
            {:reply, result, %{state | endpoint_states: new_states}}
        end
    end
  end

  @impl true
  def handle_call(:get_health, _from, state) do
    summary =
      Enum.reduce(state.endpoint_states, %{}, fn {ep, data}, acc ->
        chain = data.chain
        chain_summary = Map.get(acc, chain, %{healthy_count: 0, total_count: 0, endpoints: %{}})

        is_healthy = data.healthy and current_timestamp() >= data.cooldown_until
        health_status = if is_healthy, do: :healthy, else: :degraded

        new_eps = Map.put(chain_summary.endpoints, ep, Map.put(data, :status, health_status))

        new_summary = %{
          healthy_count: chain_summary.healthy_count + if(is_healthy, do: 1, else: 0),
          total_count: chain_summary.total_count + 1,
          endpoints: new_eps
        }

        Map.put(acc, chain, new_summary)
      end)

    {:reply, summary, state}
  end

  @impl true
  def handle_call({:register_endpoints, chain, endpoints}, _from, state) do
    current = Map.get(state.chains, chain, %{chain_id: 0, name: to_string(chain), endpoints: []})
    updated_chain = %{current | endpoints: Enum.uniq(current.endpoints ++ endpoints)}
    updated_chains = Map.put(state.chains, chain, updated_chain)

    new_states =
      Enum.reduce(endpoints, state.endpoint_states, fn ep, acc ->
        Map.put_new(acc, ep, %{
          chain: chain,
          healthy: true,
          consecutive_failures: 0,
          total_requests: 0,
          total_errors: 0,
          cooldown_until: 0,
          last_latency_ms: 0
        })
      end)

    {:reply, :ok, %{state | chains: updated_chains, endpoint_states: new_states}}
  end

  # Internal Helpers

  defp select_healthy_endpoint(endpoints, states) do
    now = current_timestamp()

    healthy =
      Enum.filter(endpoints, fn ep ->
        state = Map.get(states, ep)
        state && state.healthy && now >= state.cooldown_until
      end)

    case healthy do
      [] ->
        # If all in cooldown, pick the one with earliest cooldown expiry
        Enum.min_by(endpoints, fn ep ->
          get_in(states, [ep, :cooldown_until]) || 0
        end, fn -> nil end)

      available ->
        Enum.random(available)
    end
  end

  defp execute_rpc_with_failover(endpoint, all_endpoints, method, params, state, mock_client) do
    remaining = List.delete(all_endpoints, endpoint)

    case do_http_rpc(endpoint, method, params, mock_client) do
      {:ok, result, latency} ->
        states = record_success(state.endpoint_states, endpoint, latency)
        {{:ok, result}, states}

      {:error, reason} ->
        states = record_failure(state.endpoint_states, endpoint, state.rate_limit_config)

        case remaining do
          [] ->
            {{:error, {:all_endpoints_failed, reason}}, states}

          [next_ep | _] ->
            # Failover to next endpoint
            execute_rpc_with_failover(next_ep, remaining, method, params, %{state | endpoint_states: states}, mock_client)
        end
    end
  end

  defp do_http_rpc(_endpoint, method, params, mock_client) when is_function(mock_client, 2) do
    mock_client.(method, params)
  end

  defp do_http_rpc(endpoint, method, params, _mock_client) do
    payload = %{
      jsonrpc: "2.0",
      id: :erlang.unique_integer([:positive]),
      method: method,
      params: params
    }

    start_time = System.monotonic_time(:millisecond)

    case Req.post(endpoint, json: payload, receive_timeout: 15_000) do
      {:ok, %{status: 200, body: %{"result" => result}}} ->
        latency = System.monotonic_time(:millisecond) - start_time
        {:ok, result, latency}

      {:ok, %{status: 200, body: %{"error" => error}}} ->
        {:error, {:rpc_error, error}}

      {:ok, %{status: 429}} ->
        {:error, :rate_limited}

      {:ok, %{status: code}} ->
        {:error, {:http_error, code}}

      {:error, reason} ->
        {:error, {:transport_error, reason}}
    end
  end

  defp record_success(states, endpoint, latency) do
    Map.update(
      states,
      endpoint,
      %{
        chain: :unknown,
        healthy: true,
        consecutive_failures: 0,
        total_requests: 1,
        total_errors: 0,
        cooldown_until: 0,
        last_latency_ms: latency
      },
      fn s ->
        %{
          s
          | healthy: true,
            consecutive_failures: 0,
            total_requests: s.total_requests + 1,
            last_latency_ms: latency
        }
      end
    )
  end

  defp record_failure(states, endpoint, config) do
    now = current_timestamp()
    cooldown = now + config.cooldown_sec

    Map.update(
      states,
      endpoint,
      %{
        chain: :unknown,
        healthy: false,
        consecutive_failures: 1,
        total_requests: 1,
        total_errors: 1,
        cooldown_until: cooldown,
        last_latency_ms: 0
      },
      fn s ->
        fails = s.consecutive_failures + 1
        is_healthy = fails < config.max_consecutive_failures

        %{
          s
          | healthy: is_healthy,
            consecutive_failures: fails,
            total_requests: s.total_requests + 1,
            total_errors: s.total_errors + 1,
            cooldown_until: if(is_healthy, do: s.cooldown_until, else: cooldown)
        }
      end
    )
  end

  defp current_timestamp do
    System.system_time(:second)
  end
end
