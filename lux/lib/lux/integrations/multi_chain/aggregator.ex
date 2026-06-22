defmodule Lux.Integrations.MultiChain.Aggregator do
  @moduledoc """
  Cross-chain data aggregator for the MultiChain module.

  Aggregates data from multiple blockchain networks into a unified response.
  Supports parallel fetching with configurable concurrency.

  ## Supported Chains

  - `:ethereum` - Ethereum Mainnet
  - `:polygon` - Polygon PoS
  - `:arbitrum` - Arbitrum One
  - `:optimism` - Optimism
  - `:base` - Base
  - `:bnb` - BNB Smart Chain

  ## Usage

      {:ok, result} = Aggregator.aggregate(%{
        addresses: ["0x..."],
        operation: :balance
      })

  ## Aggregation Strategies

  - `:balance` - Fetch native token balance per address per chain
  - `:block_number` - Fetch latest block number per chain
  - `:gas_price` - Fetch current gas price per chain
  - `:tx_count` - Fetch transaction count per address per chain
  """

  alias Lux.Integrations.MultiChain.ChainAdapter

  @type operation :: :balance | :block_number | :gas_price | :tx_count
  @type address :: String.t()
  @type chain :: ChainAdapter.chain()

  @all_chains [
    ethereum: Lux.Integrations.MultiChain.Ethereum,
    polygon: Lux.Integrations.MultiChain.Polygon,
    arbitrum: Lux.Integrations.MultiChain.Arbitrum,
    optimism: Lux.Integrations.MultiChain.Optimism,
    base: Lux.Integrations.MultiChain.Base,
    bnb: Lux.Integrations.MultiChain.Bnb
  ]

  @supported_operations [:balance, :block_number, :gas_price, :tx_count]

  @doc """
  Aggregates data from multiple chains in parallel.
  """
  @spec aggregate(%{
          required(:addresses) => [address()],
          required(:operation) => operation(),
          optional(:chains) => [chain()],
          optional(:concurrency) => pos_integer(),
          optional(:block) => ChainAdapter.block_tag()
        }) :: {:ok, map()} | {:error, String.t()}
  def aggregate(%{operation: op, addresses: addrs} = input) when is_list(addrs) and op in @supported_operations do
    chains = Map.get(input, :chains, @all_chains)
    concurrency = Map.get(input, :concurrency, length(chains))
    block = Map.get(input, :block, "latest")

    tasks =
      chains
      |> Enum.take(concurrency)
      |> Enum.map(fn {chain_key, module} ->
        Task.async(fn ->
          {chain_key, module, fetch_for_chain(module, addrs, op, block)}
        end)
      end)

    results = await_tasks(tasks, concurrency * 5000)
    build_result(results, op, addrs, length(chains))
  end

  def aggregate(%{operation: op}) do
    {:error, "Unsupported operation: #{op}. Supported: #{Enum.join(@supported_operations, ", ")}"}
  end

  def aggregate(_) do
    {:error, "Invalid input: expected map with :addresses and :operation keys"}
  end

  @spec supported_chains() :: [atom()]
  def supported_chains, do: @all_chains |> Keyword.keys()

  @spec chain_adapters() :: [{atom(), module()}]
  def chain_adapters, do: @all_chains

  @spec fetch_for_chain(module(), [address()], operation(), ChainAdapter.block_tag()) ::
          {:ok, %{address() => map()}} | {:error, String.t()}
  def fetch_for_chain(module, addresses, :balance, block) do
    results =
      addresses
      |> Enum.map(fn addr ->
        case module.fetch_balance(addr, block) do
          {:ok, data} -> {addr, data}
          {:error, reason} -> {addr, {:error, reason}}
        end
      end)
    {:ok, Map.new(results)}
  end

  def fetch_for_chain(module, _addresses, :block_number, _block) do
    case module.fetch_block_number() do
      {:ok, data} -> {:ok, %{"block" => data}}
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch_for_chain(module, _addresses, :gas_price, _block) do
    case module.fetch_gas_price() do
      {:ok, data} -> {:ok, %{"gas" => data}}
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch_for_chain(module, addresses, :tx_count, block) do
    results =
      addresses
      |> Enum.map(fn addr ->
        case module.fetch_tx_count(addr, block) do
          {:ok, data} -> {addr, data}
          {:error, reason} -> {addr, {:error, reason}}
        end
      end)
    {:ok, Map.new(results)}
  end

  # --- internals ---

  defp build_result(results, operation, addresses, total_chains) do
    {success_map, error_list} =
      Enum.reduce(results, {%{}, []}, fn {chain_key, module, {:ok, data}}, {acc, errs} ->
        chain_info = %{
          chain_id: module.chain_id(),
          chain_name: module.chain_name(),
          symbol: module.symbol(),
          currency: module.native_currency()
        }
        {Map.put(acc, chain_key, %{chain: chain_info, data: data}), errs}
      end)

    {success_map, error_list} =
      Enum.reduce(results, {success_map, error_list}, fn {chain_key, module, {:error, reason}}, {acc, errs} ->
        chain_info = %{
          chain_id: module.chain_id(),
          chain_name: module.chain_name(),
          symbol: module.symbol()
        }
        err_entry = %{chain: chain_info, error: reason}
        {acc, [err_entry | errs]}
      end)

    successful_count = Map.size(success_map)
    failed_count = length(error_list)

    result = %{
      success: failed_count == 0,
      chains: success_map,
      errors: error_list,
      metadata: %{
        timestamp: DateTime.utc_now(),
        operation: operation,
        total_chains: total_chains,
        successful_chains: successful_count,
        failed_chains: failed_count,
        addresses_fetched: length(addresses)
      }
    }

    {:ok, result}
  end

  defp await_tasks(tasks, timeout) do
    Enum.map(tasks, fn {pid, ref} ->
      receive do
        {^ref, result} -> result
      after
        timeout ->
          Process.demonitor(ref, [:flush])
          {nil, nil, {:error, "Task timed out"}}
      end
    end)
  end
end
