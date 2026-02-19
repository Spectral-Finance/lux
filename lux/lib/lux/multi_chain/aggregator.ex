defmodule Lux.MultiChain.Aggregator do
  @moduledoc """
  Core multi-chain data aggregation engine.

  Provides a unified interface for querying blockchain data across multiple
  EVM-compatible chains simultaneously. Results are normalized into consistent
  `Lux.MultiChain.DataModel` structs regardless of source chain.

  ## Features

  - Cross-chain block queries
  - Multi-chain balance aggregation
  - Cross-chain transaction lookup
  - Multi-chain event/log filtering
  - Gas price comparison across chains
  - Parallel execution across chains

  ## Usage

      # Get balances across all chains
      {:ok, balances} = Lux.MultiChain.Aggregator.get_balances(
        "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
        [:ethereum, :polygon, :bsc]
      )

      # Get latest blocks from multiple chains
      {:ok, blocks} = Lux.MultiChain.Aggregator.get_latest_blocks([:ethereum, :polygon])

      # Compare gas prices
      {:ok, prices} = Lux.MultiChain.Aggregator.get_gas_prices([:ethereum, :polygon, :bsc])
  """

  alias Lux.Chain
  alias Lux.MultiChain.Cache
  alias Lux.MultiChain.Normalizer
  alias Lux.MultiChain.RpcManager

  @type chain :: atom()
  @type address :: String.t()
  @type block_ref :: String.t() | non_neg_integer()

  @doc """
  Fetches the latest block from one or more chains in parallel.

  Returns normalized `Block` structs for each chain.

  ## Examples

      {:ok, blocks} = Aggregator.get_latest_blocks([:ethereum, :polygon])
      Enum.each(blocks, fn block -> IO.puts("\#{block.chain}: \#{block.number}") end)
  """
  @spec get_latest_blocks([chain()]) :: {:ok, [Lux.MultiChain.DataModel.Block.t()]} | {:error, term()}
  def get_latest_blocks(chains) when is_list(chains) do
    results = parallel_query(chains, &fetch_latest_block/1)

    case partition_results(results) do
      {blocks, []} -> {:ok, blocks}
      {[_ | _] = blocks, _errors} -> {:ok, blocks}
      {_, errors} -> {:error, "All chains failed: #{inspect(errors)}"}
    end
  end

  @doc """
  Fetches a specific block by number from the given chain.

  ## Examples

      {:ok, block} = Aggregator.get_block(:ethereum, 18_000_000)
  """
  @spec get_block(chain(), block_ref()) :: {:ok, Lux.MultiChain.DataModel.Block.t()} | {:error, term()}
  def get_block(chain, block_number) do
    chain_config = Chain.get!(chain)
    block_param = format_block_param(block_number)

    cache_key = "block:#{block_param}"
    ttl = if block_param == "latest", do: chain_config.block_time_ms, else: :infinity

    cache_opts = if ttl == :infinity, do: [ttl: 3_600_000], else: [ttl: ttl]

    Cache.fetch_or_store(chain, cache_key, cache_opts, fn ->
      case RpcManager.call(chain, "eth_getBlockByNumber", [block_param, false]) do
        {:ok, nil} ->
          {:error, "Block not found"}

        {:ok, raw_block} ->
          {:ok, Normalizer.normalize_block(raw_block, chain, chain_config.chain_id)}

        {:error, _} = error ->
          error
      end
    end)
  end

  @doc """
  Fetches native token balances for an address across multiple chains in parallel.

  ## Examples

      {:ok, balances} = Aggregator.get_balances("0x742d...", [:ethereum, :polygon, :bsc])
      total_eth = balances |> Enum.filter(& &1.chain == :ethereum) |> hd() |> Map.get(:balance_formatted)
  """
  @spec get_balances(address(), [chain()]) ::
          {:ok, [Lux.MultiChain.DataModel.TokenBalance.t()]} | {:error, term()}
  def get_balances(address, chains) when is_list(chains) do
    results = parallel_query(chains, fn chain -> fetch_balance(chain, address) end)

    case partition_results(results) do
      {balances, []} -> {:ok, balances}
      {[_ | _] = balances, _errors} -> {:ok, balances}
      {_, errors} -> {:error, "All chains failed: #{inspect(errors)}"}
    end
  end

  @doc """
  Fetches the native token balance for an address on a single chain.

  ## Examples

      {:ok, balance} = Aggregator.get_balance(:ethereum, "0x742d...")
  """
  @spec get_balance(chain(), address()) ::
          {:ok, Lux.MultiChain.DataModel.TokenBalance.t()} | {:error, term()}
  def get_balance(chain, address) do
    fetch_balance(chain, address)
  end

  @doc """
  Fetches a transaction by hash from the specified chain.

  ## Examples

      {:ok, tx} = Aggregator.get_transaction(:ethereum, "0xabc...")
  """
  @spec get_transaction(chain(), String.t()) ::
          {:ok, Lux.MultiChain.DataModel.Transaction.t()} | {:error, term()}
  def get_transaction(chain, tx_hash) do
    chain_config = Chain.get!(chain)

    Cache.fetch_or_store(chain, "tx:#{tx_hash}", [ttl: 300_000], fn ->
      case RpcManager.call(chain, "eth_getTransactionByHash", [tx_hash]) do
        {:ok, nil} ->
          {:error, "Transaction not found"}

        {:ok, raw_tx} ->
          {:ok, Normalizer.normalize_transaction(raw_tx, chain, chain_config.chain_id)}

        {:error, _} = error ->
          error
      end
    end)
  end

  @doc """
  Searches for a transaction across multiple chains in parallel.

  Useful when the chain of origin is unknown.

  ## Examples

      {:ok, {chain, tx}} = Aggregator.find_transaction("0xabc...", [:ethereum, :polygon, :bsc])
  """
  @spec find_transaction(String.t(), [chain()]) ::
          {:ok, {chain(), Lux.MultiChain.DataModel.Transaction.t()}} | {:error, :not_found}
  def find_transaction(tx_hash, chains) when is_list(chains) do
    results = parallel_query(chains, fn chain ->
      case get_transaction(chain, tx_hash) do
        {:ok, tx} -> {:ok, {chain, tx}}
        {:error, _} -> {:error, :not_found}
      end
    end)

    case Enum.find(results, fn {_, result} -> match?({:ok, _}, result) end) do
      {_chain, {:ok, found}} -> {:ok, found}
      nil -> {:error, :not_found}
    end
  end

  @doc """
  Fetches event logs matching a filter from the specified chain.

  ## Parameters

  - `chain` - Target chain
  - `filter` - Map with filter parameters:
    - `:address` - Contract address (optional)
    - `:topics` - List of topic filters (optional)
    - `:from_block` - Start block (default: "latest" minus 100)
    - `:to_block` - End block (default: "latest")

  ## Examples

      {:ok, events} = Aggregator.get_events(:ethereum, %{
        address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
        topics: ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"],
        from_block: 18_000_000,
        to_block: 18_000_100
      })
  """
  @spec get_events(chain(), map()) ::
          {:ok, [Lux.MultiChain.DataModel.Event.t()]} | {:error, term()}
  def get_events(chain, filter) do
    chain_config = Chain.get!(chain)

    params = build_log_filter(filter)

    case RpcManager.call(chain, "eth_getLogs", [params]) do
      {:ok, raw_logs} when is_list(raw_logs) ->
        events =
          Enum.map(raw_logs, &Normalizer.normalize_event(&1, chain, chain_config.chain_id))

        {:ok, events}

      {:ok, _} ->
        {:ok, []}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Fetches event logs matching a filter from multiple chains in parallel.

  ## Examples

      {:ok, all_events} = Aggregator.get_events_multi([:ethereum, :polygon], %{
        address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
        topics: ["0xddf252ad..."]
      })
  """
  @spec get_events_multi([chain()], map()) ::
          {:ok, [Lux.MultiChain.DataModel.Event.t()]} | {:error, term()}
  def get_events_multi(chains, filter) when is_list(chains) do
    results = parallel_query(chains, fn chain -> get_events(chain, filter) end)

    {successes, _errors} = partition_results(results)

    all_events =
      successes
      |> List.flatten()
      |> Enum.sort_by(& &1.block_number, :desc)

    {:ok, all_events}
  end

  @doc """
  Fetches current gas prices from multiple chains in parallel.

  ## Examples

      {:ok, prices} = Aggregator.get_gas_prices([:ethereum, :polygon, :bsc])
      cheapest = Enum.min_by(prices, & &1.propose_gas_price)
  """
  @spec get_gas_prices([chain()]) ::
          {:ok, [Lux.MultiChain.DataModel.GasPrice.t()]} | {:error, term()}
  def get_gas_prices(chains) when is_list(chains) do
    results = parallel_query(chains, &fetch_gas_price/1)

    case partition_results(results) do
      {prices, []} -> {:ok, prices}
      {[_ | _] = prices, _errors} -> {:ok, prices}
      {_, errors} -> {:error, "All chains failed: #{inspect(errors)}"}
    end
  end

  @doc """
  Returns a summary of data across all specified chains including latest block,
  gas price, and native balance for an optional address.

  ## Examples

      {:ok, summary} = Aggregator.chain_summary([:ethereum, :polygon], address: "0x742d...")
  """
  @spec chain_summary([chain()], keyword()) :: {:ok, [map()]} | {:error, term()}
  def chain_summary(chains, opts \\ []) do
    address = Keyword.get(opts, :address)

    results =
      parallel_query(chains, fn chain ->
        with {:ok, block} <- fetch_latest_block(chain),
             {:ok, gas} <- fetch_gas_price(chain) do
          summary = %{
            chain: chain,
            chain_id: Chain.get!(chain).chain_id,
            latest_block: block.number,
            gas_price_gwei: gas.propose_gas_price,
            fast_gas_gwei: gas.fast_gas_price,
            timestamp: DateTime.utc_now()
          }

          if address do
            case fetch_balance(chain, address) do
              {:ok, balance} ->
                {:ok, Map.put(summary, :balance, balance.balance_formatted)}

              _ ->
                {:ok, summary}
            end
          else
            {:ok, summary}
          end
        end
      end)

    {successes, _} = partition_results(results)
    {:ok, successes}
  end

  # Private helpers

  defp fetch_latest_block(chain) do
    chain_config = Chain.get!(chain)

    Cache.fetch_or_store(chain, "block:latest", [ttl: chain_config.block_time_ms], fn ->
      case RpcManager.call(chain, "eth_getBlockByNumber", ["latest", false]) do
        {:ok, nil} -> {:error, "No block returned"}
        {:ok, raw_block} -> {:ok, Normalizer.normalize_block(raw_block, chain, chain_config.chain_id)}
        {:error, _} = error -> error
      end
    end)
  end

  defp fetch_balance(chain, address) do
    chain_config = Chain.get!(chain)

    Cache.fetch_or_store(chain, "balance:#{address}", [ttl: 15_000], fn ->
      case RpcManager.call(chain, "eth_getBalance", [address, "latest"]) do
        {:ok, hex_balance} ->
          {:ok, Normalizer.normalize_token_balance(hex_balance, chain, chain_config.chain_id, address: address)}

        {:error, _} = error ->
          error
      end
    end)
  end

  defp fetch_gas_price(chain) do
    chain_config = Chain.get!(chain)

    Cache.fetch_or_store(chain, "gas_price", [ttl: chain_config.block_time_ms], fn ->
      case RpcManager.call(chain, "eth_gasPrice", []) do
        {:ok, hex_price} ->
          gwei = Normalizer.wei_to_decimal(hex_price, 9)

          gas_data = %{
            "SafeGasPrice" => to_string(Float.round(gwei * 0.8, 2)),
            "ProposeGasPrice" => to_string(Float.round(gwei, 2)),
            "FastGasPrice" => to_string(Float.round(gwei * 1.2, 2))
          }

          {:ok, Normalizer.normalize_gas_price(gas_data, chain, chain_config.chain_id)}

        {:error, _} = error ->
          error
      end
    end)
  end

  defp parallel_query(chains, query_fn) do
    chains
    |> Task.async_stream(
      fn chain ->
        {chain, query_fn.(chain)}
      end,
      timeout: 30_000,
      on_timeout: :kill_task,
      max_concurrency: length(chains)
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, reason} -> {:error, reason}
    end)
  end

  defp partition_results(results) do
    Enum.reduce(results, {[], []}, fn
      {_chain, {:ok, value}}, {ok, err} -> {[value | ok], err}
      {chain, {:error, reason}}, {ok, err} -> {ok, [{chain, reason} | err]}
      {:error, reason}, {ok, err} -> {ok, [{:unknown, reason} | err]}
    end)
  end

  defp format_block_param("latest"), do: "latest"
  defp format_block_param("pending"), do: "pending"
  defp format_block_param("earliest"), do: "earliest"
  defp format_block_param(n) when is_integer(n), do: "0x" <> Integer.to_string(n, 16)
  defp format_block_param(s) when is_binary(s), do: s

  defp build_log_filter(filter) do
    params = %{}

    params =
      if filter[:address],
        do: Map.put(params, "address", filter[:address]),
        else: params

    params =
      if filter[:topics],
        do: Map.put(params, "topics", filter[:topics]),
        else: params

    params =
      if filter[:from_block],
        do: Map.put(params, "fromBlock", format_block_param(filter[:from_block])),
        else: Map.put(params, "fromBlock", "latest")

    params =
      if filter[:to_block],
        do: Map.put(params, "toBlock", format_block_param(filter[:to_block])),
        else: Map.put(params, "toBlock", "latest")

    params
  end
end
