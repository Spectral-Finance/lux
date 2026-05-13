defmodule Lux.Web3.MultiChain.Aggregator do
  @moduledoc """
  Multi-chain data aggregation helpers.
  """

  alias Lux.Web3.MultiChain.{ChainRegistry, RPCClient}

  @doc """
  Fetches the latest block number for multiple chains and normalizes results.
  """
  @spec latest_blocks([atom() | String.t() | integer()], keyword() | map()) :: {:ok, [map()]} | {:error, term()}
  def latest_blocks(chains, opts \\ %{}) do
    chains
    |> Enum.reduce_while({:ok, []}, fn chain, {:ok, acc} ->
      with {:ok, chain_info} <- ChainRegistry.fetch(chain),
           {:ok, block_hex} <- RPCClient.call(chain, "eth_blockNumber", [], opts),
           {:ok, block_number} <- parse_quantity(block_hex) do
        {:cont, {:ok, [%{chain: chain_info.key, chain_id: chain_info.chain_id, block_number: block_number} | acc]}}
      else
        error -> {:halt, {:error, {chain, error}}}
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, Enum.reverse(rows)}
      error -> error
    end
  end

  @doc """
  Builds a normalized EVM log filter for one or more chains.
  """
  @spec event_filter(map()) :: {:ok, map()} | {:error, term()}
  def event_filter(attrs) do
    with {:ok, chains} <- normalize_chains(Map.get(attrs, :chains, [])),
         {:ok, addresses} <- normalize_addresses(Map.get(attrs, :addresses, [])) do
      {:ok,
       %{
         chains: chains,
         address: addresses,
         topics: Map.get(attrs, :topics, []),
         from_block: Map.get(attrs, :from_block, "latest"),
         to_block: Map.get(attrs, :to_block, "latest")
       }}
    end
  end

  @doc """
  Normalizes JSON-RPC quantities into integers.
  """
  @spec parse_quantity(String.t() | non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, term()}
  def parse_quantity(value) when is_integer(value) and value >= 0, do: {:ok, value}

  def parse_quantity("0x" <> hex) do
    case Integer.parse(hex, 16) do
      {value, ""} when value >= 0 -> {:ok, value}
      _ -> {:error, :invalid_quantity}
    end
  end

  def parse_quantity(_value), do: {:error, :invalid_quantity}

  defp normalize_chains([]), do: {:error, :missing_chains}

  defp normalize_chains(chains) do
    chains
    |> List.wrap()
    |> Enum.reduce_while({:ok, []}, fn chain, {:ok, acc} ->
      case ChainRegistry.fetch(chain) do
        {:ok, chain_info} -> {:cont, {:ok, [chain_info.key | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      error -> error
    end
  end

  defp normalize_addresses(addresses) do
    normalized =
      addresses
      |> List.wrap()
      |> Enum.map(&String.downcase/1)

    if Enum.all?(normalized, &valid_address?/1), do: {:ok, normalized}, else: {:error, :invalid_address}
  end

  defp valid_address?("0x" <> rest), do: String.length(rest) == 40
  defp valid_address?(_address), do: false
end
