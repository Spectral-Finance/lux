defmodule Lux.Integrations.MultiChain.Aggregator do
  @moduledoc """
  Deterministic helpers for planning multi-chain EVM data aggregation.

  This module deliberately does not hold private keys, sign transactions, or
  broadcast anything. It builds JSON-RPC read requests, normalizes block/log
  responses, and prepares event query plans that can be executed by a caller
  with its own HTTP transport.
  """

  @type chain :: %{
          key: String.t(),
          chain_id: non_neg_integer(),
          chain_id_hex: String.t(),
          native_symbol: String.t(),
          rpc_url: String.t() | nil,
          explorer_url: String.t() | nil
        }

  @default_chains %{
    "ethereum" => %{
      chain_id: 1,
      native_symbol: "ETH",
      rpc_url: "https://ethereum-rpc.publicnode.com",
      explorer_url: "https://etherscan.io"
    },
    "polygon" => %{
      chain_id: 137,
      native_symbol: "MATIC",
      rpc_url: "https://polygon-bor-rpc.publicnode.com",
      explorer_url: "https://polygonscan.com"
    },
    "bsc" => %{
      chain_id: 56,
      native_symbol: "BNB",
      rpc_url: "https://bsc-rpc.publicnode.com",
      explorer_url: "https://bscscan.com"
    },
    "arbitrum" => %{
      chain_id: 42_161,
      native_symbol: "ETH",
      rpc_url: "https://arbitrum-one-rpc.publicnode.com",
      explorer_url: "https://arbiscan.io"
    },
    "optimism" => %{
      chain_id: 10,
      native_symbol: "ETH",
      rpc_url: "https://optimism-rpc.publicnode.com",
      explorer_url: "https://optimistic.etherscan.io"
    },
    "base" => %{
      chain_id: 8453,
      native_symbol: "ETH",
      rpc_url: "https://base-rpc.publicnode.com",
      explorer_url: "https://basescan.org"
    }
  }

  @doc """
  Returns supported default EVM chains.
  """
  @spec default_chains() :: %{String.t() => chain()}
  def default_chains do
    Map.new(@default_chains, fn {key, config} -> {key, build_chain(key, config)} end)
  end

  @doc """
  Normalizes chain names or custom chain maps into canonical chain records.
  """
  @spec normalize_chains([String.t() | atom() | map()]) :: {:ok, [chain()]} | {:error, term()}
  def normalize_chains(chains) when is_list(chains) do
    chains
    |> Enum.reduce_while({:ok, []}, fn chain, {:ok, acc} ->
      case normalize_chain(chain) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      error -> error
    end
  end

  def normalize_chains(_chains), do: {:error, :chains_must_be_a_list}

  @doc """
  Builds JSON-RPC requests for latest block collection.
  """
  @spec latest_block_requests([String.t() | atom() | map()]) :: {:ok, [map()]} | {:error, term()}
  def latest_block_requests(chains) do
    with {:ok, normalized} <- normalize_chains(chains) do
      {:ok, Enum.map(normalized, &rpc_request(&1, "eth_blockNumber", []))}
    end
  end

  @doc """
  Builds a JSON-RPC request envelope for a chain.
  """
  @spec rpc_request(chain(), String.t(), list(), String.t() | nil) :: map()
  def rpc_request(chain, method, params \\ [], id \\ nil) do
    %{
      chain: chain.key,
      chain_id: chain.chain_id,
      rpc_url: chain.rpc_url,
      request: %{
        jsonrpc: "2.0",
        id: id || "#{chain.key}:#{method}",
        method: method,
        params: params
      }
    }
  end

  @doc """
  Builds an `eth_getLogs` request for a contract/event filter.
  """
  @spec event_filter(String.t() | atom() | map(), String.t(), String.t() | nil, map()) ::
          {:ok, map()} | {:error, term()}
  def event_filter(chain, address, event_topic, opts \\ %{}) do
    with {:ok, normalized} <- normalize_chain(chain),
         {:ok, clean_address} <- normalize_address(address),
         {:ok, from_block} <- block_tag(value(opts, :from_block) || "latest"),
         {:ok, to_block} <- block_tag(value(opts, :to_block) || "latest") do
      topics =
        [event_topic | List.wrap(value(opts, :topics))]
        |> Enum.reject(&is_nil/1)

      filter =
        %{
          address: clean_address,
          fromBlock: from_block,
          toBlock: to_block,
          topics: topics
        }
        |> maybe_put(:blockHash, value(opts, :block_hash))

      {:ok, rpc_request(normalized, "eth_getLogs", [filter])}
    end
  end

  @doc """
  Normalizes a chain latest-block JSON-RPC response.
  """
  @spec normalize_block_response(String.t() | atom() | map(), map()) :: {:ok, map()} | {:error, term()}
  def normalize_block_response(chain, response) do
    with {:ok, normalized} <- normalize_chain(chain),
         {:ok, block_number} <- parse_quantity(value(response, :result)) do
      {:ok,
       %{
         chain: normalized.key,
         chain_id: normalized.chain_id,
         block_number: block_number,
         block_number_hex: quantity(block_number)
       }}
    end
  end

  @doc """
  Aggregates latest-block responses into lag and high-watermark metadata.
  """
  @spec aggregate_latest_blocks([map()]) :: map()
  def aggregate_latest_blocks(responses) when is_list(responses) do
    blocks =
      responses
      |> Enum.map(fn response ->
        chain = value(response, :chain) || value(response, :chain_key)
        body = value(response, :response) || response

        case normalize_block_response(chain, body) do
          {:ok, block} -> block
          {:error, reason} -> %{chain: to_string(chain), error: reason}
        end
      end)

    valid_blocks = Enum.filter(blocks, &Map.has_key?(&1, :block_number))
    block_numbers = Enum.map(valid_blocks, & &1.block_number)
    highest = if block_numbers == [], do: nil, else: Enum.max(block_numbers)
    lowest = if block_numbers == [], do: nil, else: Enum.min(block_numbers)

    %{
      chains: blocks,
      highest_block: highest,
      lowest_block: lowest,
      lag_by_chain: lag_by_chain(valid_blocks, highest)
    }
  end

  @doc """
  Normalizes an EVM log from `eth_getLogs`.
  """
  @spec normalize_log(String.t() | atom() | map(), map()) :: {:ok, map()} | {:error, term()}
  def normalize_log(chain, log) do
    with {:ok, normalized} <- normalize_chain(chain),
         {:ok, block_number} <- parse_quantity(value(log, :blockNumber)),
         {:ok, log_index} <- parse_quantity(value(log, :logIndex) || "0x0") do
      {:ok,
       %{
         chain: normalized.key,
         chain_id: normalized.chain_id,
         address: value(log, :address),
         topics: value(log, :topics) || [],
         data: value(log, :data),
         transaction_hash: value(log, :transactionHash),
         block_hash: value(log, :blockHash),
         block_number: block_number,
         log_index: log_index,
         removed: value(log, :removed) || false
       }}
    end
  end

  @doc """
  Filters normalized logs by chain, address, topic, and block range.
  """
  @spec query_events([map()], map()) :: [map()]
  def query_events(events, opts \\ %{}) when is_list(events) do
    events
    |> Enum.filter(&matches_chain?(&1, value(opts, :chain)))
    |> Enum.filter(&matches_address?(&1, value(opts, :address)))
    |> Enum.filter(&matches_topic?(&1, value(opts, :topic)))
    |> Enum.filter(&matches_block_range?(&1, value(opts, :from_block), value(opts, :to_block)))
  end

  @doc """
  Builds a polling/subscription plan for chains and event filters.
  """
  @spec subscription_plan([String.t() | atom() | map()], [map()], map()) ::
          {:ok, map()} | {:error, term()}
  def subscription_plan(chains, filters, opts \\ %{}) when is_list(filters) do
    with {:ok, normalized_chains} <- normalize_chains(chains) do
      normalized_filters =
        Enum.map(filters, fn filter ->
          %{
            name: value(filter, :name),
            address: value(filter, :address),
            topic: value(filter, :topic),
            from_block: value(filter, :from_block) || "latest",
            to_block: value(filter, :to_block) || "latest"
          }
        end)

      with {:ok, requests} <- event_requests(normalized_chains, normalized_filters) do
        {:ok,
         %{
           mode: value(opts, :mode) || :poll,
           poll_interval_ms: value(opts, :poll_interval_ms) || 12_000,
           chains: normalized_chains,
           filters: normalized_filters,
           rpc_requests: requests,
           retention: retention_policy(opts)
         }}
      end
    end
  end

  def subscription_plan(_chains, _filters, _opts), do: {:error, :filters_must_be_a_list}

  @doc """
  Builds a retention policy for indexed data.
  """
  @spec retention_policy(map()) :: map()
  def retention_policy(opts \\ %{}) do
    %{
      keep_raw_logs_blocks: value(opts, :keep_raw_logs_blocks) || 250_000,
      compact_after_blocks: value(opts, :compact_after_blocks) || 50_000,
      checkpoint_every_blocks: value(opts, :checkpoint_every_blocks) || 1_000,
      archive_strategy: value(opts, :archive_strategy) || :compact_to_daily_partitions
    }
  end

  @doc """
  Converts an integer into an Ethereum JSON-RPC quantity.
  """
  @spec quantity(non_neg_integer()) :: String.t()
  def quantity(number) when is_integer(number) and number >= 0 do
    "0x" <> Integer.to_string(number, 16)
  end

  @doc """
  Parses an Ethereum JSON-RPC quantity.
  """
  @spec parse_quantity(String.t() | non_neg_integer()) :: {:ok, non_neg_integer()} | {:error, term()}
  def parse_quantity(number) when is_integer(number) and number >= 0, do: {:ok, number}

  def parse_quantity("0x" <> hex) when byte_size(hex) > 0 do
    case Integer.parse(hex, 16) do
      {number, ""} -> {:ok, number}
      _ -> {:error, :invalid_quantity}
    end
  end

  def parse_quantity(_number), do: {:error, :invalid_quantity}

  defp normalize_chain(chain) when is_atom(chain), do: chain |> Atom.to_string() |> normalize_chain()

  defp normalize_chain(chain) when is_binary(chain) do
    key = String.downcase(chain)

    case @default_chains[key] do
      nil -> {:error, {:unsupported_chain, chain}}
      config -> {:ok, build_chain(key, config)}
    end
  end

  defp normalize_chain(%{} = chain) do
    key = chain |> value(:key) |> chain_key()
    chain_id = value(chain, :chain_id)

    cond do
      key == "" -> {:error, :missing_chain_key}
      not is_integer(chain_id) or chain_id <= 0 -> {:error, {:invalid_chain_id, key}}
      true -> {:ok, build_chain(key, chain)}
    end
  end

  defp normalize_chain(chain), do: {:error, {:invalid_chain, chain}}

  defp build_chain(key, config) do
    chain_id = value(config, :chain_id)

    %{
      key: key,
      chain_id: chain_id,
      chain_id_hex: quantity(chain_id),
      native_symbol: value(config, :native_symbol) || "ETH",
      rpc_url: value(config, :rpc_url),
      explorer_url: value(config, :explorer_url)
    }
  end

  defp block_tag(tag) when tag in ["earliest", "latest", "pending"], do: {:ok, tag}
  defp block_tag(number) when is_integer(number) and number >= 0, do: {:ok, quantity(number)}

  defp block_tag("0x" <> _ = quantity) do
    case parse_quantity(quantity) do
      {:ok, _number} -> {:ok, quantity}
      error -> error
    end
  end

  defp block_tag(_tag), do: {:error, :invalid_block_tag}

  defp event_requests(chains, filters) do
    Enum.reduce_while(chains, {:ok, []}, fn chain, {:ok, acc} ->
      case event_requests_for_chain(chain, filters) do
        {:ok, requests} -> {:cont, {:ok, acc ++ requests}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp event_requests_for_chain(chain, filters) do
    Enum.reduce_while(filters, {:ok, []}, fn filter, {:ok, acc} ->
      case event_filter(chain, filter.address, filter.topic, filter) do
        {:ok, request} -> {:cont, {:ok, [request | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, requests} -> {:ok, Enum.reverse(requests)}
      error -> error
    end
  end

  defp chain_key(nil), do: ""
  defp chain_key(key), do: key |> to_string() |> String.downcase()

  defp normalize_address("0x" <> rest = address) when byte_size(rest) == 40 do
    if String.match?(rest, ~r/^[0-9a-fA-F]+$/) do
      {:ok, String.downcase(address)}
    else
      {:error, :invalid_address}
    end
  end

  defp normalize_address(_address), do: {:error, :invalid_address}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp lag_by_chain(_blocks, nil), do: %{}

  defp lag_by_chain(blocks, highest) do
    Map.new(blocks, fn block -> {block.chain, highest - block.block_number} end)
  end

  defp matches_chain?(_event, nil), do: true
  defp matches_chain?(event, chain), do: value(event, :chain) == to_string(chain)

  defp matches_address?(_event, nil), do: true

  defp matches_address?(event, address) do
    String.downcase(to_string(value(event, :address))) == String.downcase(to_string(address))
  end

  defp matches_topic?(_event, nil), do: true
  defp matches_topic?(event, topic), do: topic in List.wrap(value(event, :topics))

  defp matches_block_range?(event, from_block, to_block) do
    block_number = value(event, :block_number) || 0
    after_start? = is_nil(from_block) or block_number >= from_block
    before_end? = is_nil(to_block) or block_number <= to_block

    after_start? and before_end?
  end

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, to_string(key))
  defp value(_map, _key), do: nil
end
