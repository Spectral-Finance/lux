defmodule Lux.Integrations.Web3.Chain.RpcManager do
  @moduledoc """
  Multi-chain RPC endpoint manager with health tracking, load balancing,
  and automatic failover.
  """

  use GenServer

  @default_chains %{
    ethereum: %{
      chain_id: 1,
      name: "Ethereum",
      symbol: "ETH",
      rpcs: ["https://eth.llamarpc.com", "https://rpc.ankr.com/eth", "https://ethereum-rpc.publicnode.com"],
      block_time_ms: 12_000
    },
    polygon: %{
      chain_id: 137,
      name: "Polygon",
      symbol: "MATIC",
      rpcs: ["https://polygon-rpc.com", "https://rpc.ankr.com/polygon"],
      block_time_ms: 2_000
    },
    arbitrum: %{
      chain_id: 42161,
      name: "Arbitrum One",
      symbol: "ETH",
      rpcs: ["https://arb1.arbitrum.io/rpc", "https://rpc.ankr.com/arbitrum"],
      block_time_ms: 250
    },
    optimism: %{
      chain_id: 10,
      name: "Optimism",
      symbol: "ETH",
      rpcs: ["https://mainnet.optimism.io", "https://rpc.ankr.com/optimism"],
      block_time_ms: 2_000
    },
    base: %{
      chain_id: 8453,
      name: "Base",
      symbol: "ETH",
      rpcs: ["https://mainnet.base.org", "https://rpc.ankr.com/base"],
      block_time_ms: 2_000
    },
    bsc: %{
      chain_id: 56,
      name: "BNB Smart Chain",
      symbol: "BNB",
      rpcs: ["https://bsc-dataseed.binance.org", "https://rpc.ankr.com/bsc"],
      block_time_ms: 3_000
    },
    avalanche: %{
      chain_id: 43114,
      name: "Avalanche C-Chain",
      symbol: "AVAX",
      rpcs: ["https://api.avax.network/ext/bc/C/rpc", "https://rpc.ankr.com/avalanche"],
      block_time_ms: 2_000
    }
  }

  # Client API

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def get_rpc(pid \\ __MODULE__, chain) do
    GenServer.call(pid, {:get_rpc, chain})
  end

  def report_error(pid \\ __MODULE__, chain, rpc_url) do
    GenServer.cast(pid, {:report_error, chain, rpc_url})
  end

  def report_success(pid \\ __MODULE__, chain, rpc_url, latency_ms) do
    GenServer.cast(pid, {:report_success, chain, rpc_url, latency_ms})
  end

  def chain_info(pid \\ __MODULE__, chain) do
    GenServer.call(pid, {:chain_info, chain})
  end

  def supported_chains(pid \\ __MODULE__) do
    GenServer.call(pid, :supported_chains)
  end

  def health(pid \\ __MODULE__) do
    GenServer.call(pid, :health)
  end

  # Server

  @impl true
  def init(opts) do
    chains = opts[:chains] || @default_chains
    health = Map.new(chains, fn {chain, config} ->
      rpc_health = Map.new(config.rpcs, fn rpc ->
        {rpc, %{errors: 0, successes: 0, avg_latency_ms: 0, last_error: nil}}
      end)
      {chain, rpc_health}
    end)

    {:ok, %{chains: chains, health: health}}
  end

  @impl true
  def handle_call({:get_rpc, chain}, _from, state) do
    case Map.get(state.chains, chain) do
      nil ->
        {:reply, {:error, :unknown_chain}, state}
      config ->
        rpc_health = Map.get(state.health, chain, %{})
        # Pick healthiest RPC (least errors, lowest latency)
        best = config.rpcs
          |> Enum.sort_by(fn rpc ->
            h = Map.get(rpc_health, rpc, %{errors: 0, avg_latency_ms: 0})
            {h.errors, h.avg_latency_ms}
          end)
          |> hd()
        {:reply, {:ok, best}, state}
    end
  end

  @impl true
  def handle_call({:chain_info, chain}, _from, state) do
    case Map.get(state.chains, chain) do
      nil -> {:reply, {:error, :unknown_chain}, state}
      config -> {:reply, {:ok, config}, state}
    end
  end

  @impl true
  def handle_call(:supported_chains, _from, state) do
    chains = Enum.map(state.chains, fn {key, config} ->
      %{key: key, name: config.name, chain_id: config.chain_id, symbol: config.symbol}
    end)
    {:reply, chains, state}
  end

  @impl true
  def handle_call(:health, _from, state) do
    {:reply, state.health, state}
  end

  @impl true
  def handle_cast({:report_error, chain, rpc_url}, state) do
    health = update_in(state.health, [chain, rpc_url], fn
      nil -> %{errors: 1, successes: 0, avg_latency_ms: 0, last_error: DateTime.utc_now()}
      h -> %{h | errors: h.errors + 1, last_error: DateTime.utc_now()}
    end)
    {:noreply, %{state | health: health}}
  end

  @impl true
  def handle_cast({:report_success, chain, rpc_url, latency_ms}, state) do
    health = update_in(state.health, [chain, rpc_url], fn
      nil -> %{errors: 0, successes: 1, avg_latency_ms: latency_ms, last_error: nil}
      h ->
        new_avg = (h.avg_latency_ms * h.successes + latency_ms) / (h.successes + 1)
        %{h | successes: h.successes + 1, avg_latency_ms: round(new_avg)}
    end)
    {:noreply, %{state | health: health}}
  end
end
