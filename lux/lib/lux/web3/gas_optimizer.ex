defmodule Lux.Web3.GasOptimizer do
  @moduledoc """
  Gas Optimization and Transaction Management System.

  Provides EIP-1559 gas price prediction, priority fee optimization, Multicall3
  transaction batching, Replace-By-Fee (speed-up/cancel) replacement building,
  MEV risk analysis & private bundle creation, pre-flight transaction simulation,
  and historical gas cost reporting.
  """

  alias Lux.Web3.GasOptimizer.Batcher
  alias Lux.Web3.GasOptimizer.FeePredictor
  alias Lux.Web3.GasOptimizer.MEVProtection
  alias Lux.Web3.GasOptimizer.Replacement
  alias Lux.Web3.GasOptimizer.Simulator

  @cost_table :lux_web3_gas_cost_ledger

  @default_endpoints %{
    ethereum: "https://eth.llamarpc.com",
    polygon: "https://polygon-rpc.com",
    bsc: "https://bsc-dataseed.binance.org",
    arbitrum: "https://arb1.arbitrum.io/rpc",
    optimism: "https://mainnet.optimism.io",
    base: "https://mainnet.base.org"
  }

  @doc """
  Initializes the ETS ledger for gas cost tracking.
  """
  @spec ensure_started() :: :ok
  def ensure_started do
    case :ets.whereis(@cost_table) do
      :undefined ->
        try do
          :ets.new(@cost_table, [:named_table, :public, :ordered_set, read_concurrency: true])
          :ok
        rescue
          ArgumentError -> :ok
        end

      _tid ->
        :ok
    end
  end

  @doc """
  Resets all recorded gas cost history.
  """
  @spec reset!() :: :ok
  def reset! do
    ensure_started()
    :ets.delete_all_objects(@cost_table)
    :ok
  end

  @doc """
  Fetches `eth_feeHistory` from the target chain and computes optimal EIP-1559
  fee parameters for the requested strategy tier (`:economy`, `:standard`, `:fast`, `:urgent`).
  """
  @spec predict_gas_fees(atom(), FeePredictor.tier(), keyword()) ::
          {:ok, FeePredictor.prediction()} | {:error, term()}
  def predict_gas_fees(chain \\ :ethereum, tier \\ :standard, opts \\ []) do
    block_count = Keyword.get(opts, :block_count, 5)
    percentiles = [10.0, 50.0, 80.0, 95.0]

    with {:ok, fee_history} when is_map(fee_history) <-
           rpc_call(chain, "eth_feeHistory", [block_count, "latest", percentiles], opts) do
      FeePredictor.analyze_fee_history(chain, fee_history, tier)
    end
  end

  @doc """
  Simulates a transaction on the target chain using `eth_call` and `eth_estimateGas`.
  """
  @spec simulate_transaction(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def simulate_transaction(tx, opts \\ []) when is_map(tx) do
    chain = Map.get(tx, :chain, :ethereum)
    caller = fn method, params -> rpc_call(chain, method, params, opts) end
    Simulator.simulate(tx, caller)
  end

  @doc """
  Records a completed transaction's gas usage and savings into the cost analysis ledger.
  """
  @spec record_gas_usage(map()) :: {:ok, map()}
  def record_gas_usage(attrs) when is_map(attrs) do
    ensure_started()
    seq = System.unique_integer([:positive, :monotonic])
    gas_used = Map.get(attrs, :gas_used, 21_000)
    gas_saved = Map.get(attrs, :gas_saved, 0)
    effective_price_wei = Map.get(attrs, :effective_gas_price_wei, 20_000_000_000)
    native_usd = Map.get(attrs, :native_token_usd, 2_500.0)

    total_wei = gas_used * effective_price_wei
    saved_wei = gas_saved * effective_price_wei
    cost_usd = Float.round(total_wei / 1.0e18 * native_usd, 6)
    saved_usd = Float.round(saved_wei / 1.0e18 * native_usd, 6)

    entry = %{
      id: seq,
      chain: Map.get(attrs, :chain, :ethereum),
      tx_hash: Map.get(attrs, :tx_hash),
      gas_used: gas_used,
      gas_saved: gas_saved,
      effective_gas_price_wei: effective_price_wei,
      total_cost_wei: total_wei,
      saved_wei: saved_wei,
      cost_usd: cost_usd,
      saved_usd: saved_usd,
      timestamp: DateTime.utc_now()
    }

    :ets.insert(@cost_table, {seq, entry})
    {:ok, entry}
  end

  @doc """
  Generates an aggregated cost analysis and gas optimization savings report.
  """
  @spec cost_report(keyword()) :: map()
  def cost_report(opts \\ []) do
    ensure_started()
    chain_filter = Keyword.get(opts, :chain)

    entries =
      @cost_table
      |> :ets.tab2list()
      |> Enum.map(fn {_seq, entry} -> entry end)
      |> Enum.filter(fn entry -> is_nil(chain_filter) or entry.chain == chain_filter end)

    total_gas_used = Enum.reduce(entries, 0, &(&1.gas_used + &2))
    total_gas_saved = Enum.reduce(entries, 0, &(&1.gas_saved + &2))
    total_cost_wei = Enum.reduce(entries, 0, &(&1.total_cost_wei + &2))
    total_cost_usd = Float.round(Enum.reduce(entries, 0.0, &(&1.cost_usd + &2)), 6)
    total_saved_usd = Float.round(Enum.reduce(entries, 0.0, &(&1.saved_usd + &2)), 6)

    %{
      transaction_count: length(entries),
      total_gas_used: total_gas_used,
      total_gas_saved: total_gas_saved,
      total_cost_wei: total_cost_wei,
      total_cost_usd: total_cost_usd,
      total_saved_usd: total_saved_usd,
      entries: entries
    }
  end

  defdelegate build_batch(calls, opts \\ []), to: Batcher
  defdelegate speed_up(pending_tx, opts \\ []), to: Replacement
  defdelegate cancel(pending_tx, opts \\ []), to: Replacement
  defdelegate analyze_mev_risk(tx), to: MEVProtection, as: :analyze_risk
  defdelegate build_private_bundle(raw_txs, target_block, opts \\ []), to: MEVProtection

  defp rpc_call(chain, method, params, opts) do
    default_url = Map.get(@default_endpoints, chain, "https://eth.llamarpc.com")
    url = Keyword.get(opts, :rpc_url, default_url)

    payload = %{
      "jsonrpc" => "2.0",
      "id" => System.unique_integer([:positive]),
      "method" => method,
      "params" => params
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
      {:ok, %{status: 200, body: %{"result" => result}}} ->
        {:ok, result}

      {:ok, %{status: 200, body: %{"error" => err}}} ->
        {:error, {:rpc_error, err}}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
