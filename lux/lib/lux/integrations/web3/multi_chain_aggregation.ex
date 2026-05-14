defmodule Lux.Integrations.Web3.MultiChainAggregation do
  @moduledoc """
  Transport-neutral multi-chain aggregation helpers for EVM-compatible networks.

  The module builds JSON-RPC request plans, normalizes event filters, aggregates
  collected responses, and queries in-memory datasets. It keeps network I/O out
  of the core so callers can plug in Req, Ethers, or another RPC transport.
  """

  @default_chains %{
    ethereum: %{chain_id: 1, name: "Ethereum", currency: "ETH", average_block_time_ms: 12_000},
    polygon: %{chain_id: 137, name: "Polygon", currency: "MATIC", average_block_time_ms: 2_000},
    bsc: %{chain_id: 56, name: "BNB Smart Chain", currency: "BNB", average_block_time_ms: 3_000},
    arbitrum: %{
      chain_id: 42161,
      name: "Arbitrum One",
      currency: "ETH",
      average_block_time_ms: 250
    },
    optimism: %{chain_id: 10, name: "Optimism", currency: "ETH", average_block_time_ms: 2_000},
    base: %{chain_id: 8453, name: "Base", currency: "ETH", average_block_time_ms: 2_000}
  }

  @default_actions [:latest_block, :logs]
  @default_retention %{blocks: 7, transactions: 30, logs: 30, metrics: 90}
  @known_slugs %{
    "ethereum" => :ethereum,
    "polygon" => :polygon,
    "bsc" => :bsc,
    "arbitrum" => :arbitrum,
    "optimism" => :optimism,
    "base" => :base
  }

  @type chain :: atom() | String.t() | map()
  @type request_plan :: map()
  @type response :: map()

  @doc """
  Returns normalized chain metadata. Empty input returns default major EVM chains;
  explicit input returns only those chains.
  """
  @spec registry([chain()] | map()) :: map()
  def registry(chains \\ [])
  def registry(chains) when chains in [nil, []], do: @default_chains

  def registry(chains) do
    chains
    |> List.wrap()
    |> Map.new(fn chain ->
      normalized = normalize_chain(chain)
      {normalized.slug, Map.delete(normalized, :slug)}
    end)
  end

  @doc """
  Builds chain-aware JSON-RPC request plans.
  """
  @spec plan_requests([chain()] | map(), keyword() | map()) :: request_plan()
  def plan_requests(chains \\ [], opts \\ %{}) do
    opts = normalize_options(opts)
    registry = registry(chains)

    actions =
      opts |> Map.get(:actions, @default_actions) |> List.wrap() |> Enum.map(&normalize_action/1)

    filter = normalize_event_filter(Map.get(opts, :filter, %{}))
    request_id_start = normalize_integer(Map.get(opts, :request_id_start, 1)) || 1

    requests =
      registry
      |> Enum.sort_by(fn {slug, _meta} -> to_string(slug) end)
      |> Enum.flat_map(fn {slug, meta} ->
        Enum.map(actions, fn action ->
          build_rpc_request(slug, meta, action, filter)
        end)
      end)
      |> Enum.with_index(request_id_start)
      |> Enum.map(fn {request, id} -> put_in(request, [:payload, :id], id) end)

    %{
      chains: registry,
      filter: filter,
      requests: requests,
      summary: %{
        chains: map_size(registry),
        actions: actions,
        request_count: length(requests),
        rate_limit: Map.get(opts, :rate_limit, %{max_concurrency: 4, retry_attempts: 2})
      }
    }
  end

  @doc """
  Normalizes a user-provided eth_getLogs filter.
  """
  @spec normalize_event_filter(map()) :: map()
  def normalize_event_filter(filter) when is_map(filter) do
    %{
      address: filter |> fetch_value(:address) |> normalize_address_list(),
      topics: filter |> fetch_value(:topics) |> normalize_topics(),
      from_block:
        normalize_block(
          fetch_value(filter, :from_block) || fetch_value(filter, :fromBlock) || "latest"
        ),
      to_block:
        normalize_block(
          fetch_value(filter, :to_block) || fetch_value(filter, :toBlock) || "latest"
        )
    }
    |> drop_empty_values()
  end

  @doc """
  Aggregates JSON-RPC response envelopes into a queryable data snapshot.
  """
  @spec aggregate_responses([response()], keyword() | map()) :: map()
  def aggregate_responses(responses, opts \\ %{}) do
    opts = normalize_options(opts)
    normalized = Enum.map(responses, &normalize_response/1)
    generated_at = Map.get(opts, :generated_at, utc_now())

    %{
      generated_at: generated_at,
      latest_blocks: latest_blocks(normalized),
      logs: normalized |> Enum.filter(&(&1.type == :logs)) |> Enum.flat_map(& &1.rows),
      transactions:
        normalized |> Enum.filter(&(&1.type == :transactions)) |> Enum.flat_map(& &1.rows),
      errors: Enum.filter(normalized, &Map.get(&1, :error)),
      health: health_summary(normalized),
      performance: performance_summary(normalized),
      retention: retention_plan(Map.get(opts, :retention, %{}))
    }
  end

  @doc """
  Queries an aggregated dataset with chain/type/address/topic filters.
  """
  @spec query(map(), keyword() | map()) :: map()
  def query(dataset, opts \\ %{}) do
    opts = normalize_options(opts)
    type = opts |> Map.get(:type, :logs) |> normalize_dataset_type()
    rows = Map.get(dataset, type, [])

    filtered =
      rows
      |> filter_by(:chain, Map.get(opts, :chain))
      |> filter_by(:address, Map.get(opts, :address))
      |> filter_topic(Map.get(opts, :topic))
      |> Enum.drop(normalize_integer(Map.get(opts, :offset, 0)) || 0)
      |> Enum.take(normalize_integer(Map.get(opts, :limit, 100)) || 100)

    %{
      rows: filtered,
      summary: %{
        type: type,
        returned: length(filtered),
        total_available: length(rows)
      }
    }
  end

  @doc """
  Builds a retention policy for stored multi-chain data.
  """
  @spec retention_plan(keyword() | map()) :: map()
  def retention_plan(overrides \\ %{}) do
    policy = Map.merge(@default_retention, normalize_options(overrides))

    %{
      policy_days: policy,
      compaction: %{
        blocks: :latest_only_after_cutoff,
        transactions: :daily_partition_after_cutoff,
        logs: :topic_and_address_partition_after_cutoff,
        metrics: :hourly_rollup_after_cutoff
      }
    }
  end

  defp build_rpc_request(chain, meta, :latest_block, _filter) do
    request(chain, meta, :latest_block, "eth_blockNumber", [])
  end

  defp build_rpc_request(chain, meta, :logs, filter) do
    request(chain, meta, :logs, "eth_getLogs", [rpc_filter(filter)])
  end

  defp build_rpc_request(chain, meta, :transaction_count, filter) do
    address = filter.address |> List.wrap() |> List.first()

    request(chain, meta, :transaction_count, "eth_getTransactionCount", [
      address,
      Map.get(filter, :to_block, "latest")
    ])
  end

  defp build_rpc_request(chain, meta, :balance, filter) do
    address = filter.address |> List.wrap() |> List.first()

    request(chain, meta, :balance, "eth_getBalance", [
      address,
      Map.get(filter, :to_block, "latest")
    ])
  end

  defp request(chain, meta, type, method, params) do
    %{
      chain: chain,
      chain_id: meta.chain_id,
      endpoint: Map.get(meta, :rpc_url),
      type: type,
      payload: %{
        jsonrpc: "2.0",
        id: nil,
        method: method,
        params: params
      },
      retry: %{attempts: 2, backoff_ms: meta.average_block_time_ms}
    }
  end

  defp rpc_filter(filter) do
    %{}
    |> maybe_put("address", Map.get(filter, :address))
    |> maybe_put("topics", Map.get(filter, :topics))
    |> maybe_put("fromBlock", Map.get(filter, :from_block))
    |> maybe_put("toBlock", Map.get(filter, :to_block))
  end

  defp normalize_response(response) when is_map(response) do
    chain = response |> fetch_value(:chain) |> normalize_slug()
    type = response |> fetch_value(:type) |> normalize_dataset_type()
    result = fetch_value(response, :result)
    error = fetch_value(response, :error)

    %{
      chain: chain,
      chain_id: fetch_value(response, :chain_id),
      type: type,
      latency_ms: normalize_integer(fetch_value(response, :latency_ms)),
      result: result,
      rows: normalize_rows(chain, type, result),
      error: error
    }
    |> drop_empty_values()
  end

  defp normalize_rows(chain, :logs, result) when is_list(result) do
    Enum.map(result, fn log ->
      %{
        chain: chain,
        type: :log,
        address: log |> fetch_value(:address) |> normalize_address(),
        topics: fetch_value(log, :topics) || [],
        data: fetch_value(log, :data),
        block_number: normalize_hex_integer(fetch_value(log, :blockNumber)),
        transaction_hash: fetch_value(log, :transactionHash),
        log_index: normalize_hex_integer(fetch_value(log, :logIndex))
      }
      |> drop_empty_values()
    end)
  end

  defp normalize_rows(chain, :transactions, result) when is_list(result) do
    Enum.map(result, &Map.put(&1, :chain, chain))
  end

  defp normalize_rows(_chain, _type, _result), do: []

  defp latest_blocks(responses) do
    responses
    |> Enum.filter(&(&1.type == :latest_block and is_nil(Map.get(&1, :error))))
    |> Map.new(fn response -> {response.chain, normalize_hex_integer(response.result)} end)
  end

  defp health_summary(responses) do
    total = length(responses)
    errors = Enum.count(responses, &Map.get(&1, :error))

    %{
      total_responses: total,
      successful_responses: total - errors,
      failed_responses: errors,
      error_rate: safe_ratio(errors, total),
      chains_with_errors:
        responses |> Enum.filter(&Map.get(&1, :error)) |> Enum.map(& &1.chain) |> Enum.uniq()
    }
  end

  defp performance_summary(responses) do
    latencies =
      responses
      |> Enum.map(&Map.get(&1, :latency_ms))
      |> Enum.filter(&is_integer/1)
      |> Enum.sort()

    %{
      samples: length(latencies),
      avg_latency_ms: average(latencies),
      p95_latency_ms: percentile(latencies, 0.95),
      max_latency_ms: percentile(latencies, 1.0)
    }
  end

  defp filter_by(rows, _key, nil), do: rows

  defp filter_by(rows, key, value),
    do: Enum.filter(rows, &(Map.get(&1, key) == normalize_filter_value(key, value)))

  defp filter_topic(rows, nil), do: rows

  defp filter_topic(rows, topic) do
    Enum.filter(rows, fn row ->
      topic in Map.get(row, :topics, [])
    end)
  end

  defp normalize_filter_value(:chain, value), do: normalize_slug(value)
  defp normalize_filter_value(:address, value), do: normalize_address(value)
  defp normalize_filter_value(_key, value), do: value

  defp normalize_chain(chain) when is_atom(chain) or is_binary(chain) do
    slug = normalize_slug(chain)

    base =
      Map.get(@default_chains, slug, %{
        chain_id: nil,
        name: to_string(slug),
        currency: nil,
        average_block_time_ms: 12_000
      })

    Map.put(base, :slug, slug)
  end

  defp normalize_chain(chain) when is_map(chain) do
    slug =
      chain |> fetch_value(:slug) || chain |> fetch_value(:name) || chain |> fetch_value(:chain)

    slug = normalize_slug(slug)
    base = Map.get(@default_chains, slug, %{})

    base
    |> Map.merge(%{
      slug: slug,
      chain_id:
        fetch_value(chain, :chain_id) || fetch_value(chain, :chainId) || Map.get(base, :chain_id),
      name: fetch_value(chain, :name) || Map.get(base, :name) || to_string(slug),
      currency: fetch_value(chain, :currency) || Map.get(base, :currency),
      rpc_url: fetch_value(chain, :rpc_url) || fetch_value(chain, :rpcUrl),
      average_block_time_ms:
        normalize_integer(fetch_value(chain, :average_block_time_ms)) ||
          Map.get(base, :average_block_time_ms, 12_000)
    })
  end

  defp normalize_slug(value) when is_atom(value), do: value

  defp normalize_slug(value) when is_binary(value) do
    slug =
      value
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "_")
      |> String.trim("_")

    Map.get(@known_slugs, slug, slug)
  end

  defp normalize_slug(_value), do: :unknown

  defp normalize_action(value) when is_atom(value), do: value

  defp normalize_action(value) when is_binary(value) do
    case value |> String.downcase() |> String.replace("-", "_") do
      "latest_block" -> :latest_block
      "logs" -> :logs
      "transaction_count" -> :transaction_count
      "balance" -> :balance
      _ -> :latest_block
    end
  end

  defp normalize_action(_value), do: :latest_block

  defp normalize_dataset_type(value) when is_atom(value), do: value

  defp normalize_dataset_type(value) when is_binary(value) do
    case value |> String.downcase() |> String.replace("-", "_") do
      "log" -> :logs
      "logs" -> :logs
      "transaction" -> :transactions
      "transactions" -> :transactions
      "latest_block" -> :latest_block
      _ -> :logs
    end
  end

  defp normalize_dataset_type(_value), do: :logs

  defp normalize_address_list(nil), do: []

  defp normalize_address_list(addresses) when is_list(addresses),
    do: Enum.map(addresses, &normalize_address/1)

  defp normalize_address_list(address), do: [normalize_address(address)]

  defp normalize_address(nil), do: nil
  defp normalize_address(address), do: address |> to_string() |> String.downcase()

  defp normalize_topics(nil), do: []
  defp normalize_topics(topics) when is_list(topics), do: topics
  defp normalize_topics(topic), do: [topic]

  defp normalize_block(value) when is_integer(value), do: "0x" <> Integer.to_string(value, 16)
  defp normalize_block(value) when value in ["latest", "pending", "earliest"], do: value
  defp normalize_block(value) when is_binary(value), do: value
  defp normalize_block(_value), do: "latest"

  defp normalize_hex_integer(nil), do: nil
  defp normalize_hex_integer(value) when is_integer(value), do: value

  defp normalize_hex_integer("0x" <> hex) do
    case Integer.parse(hex, 16) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp normalize_hex_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp normalize_hex_integer(_value), do: nil

  defp normalize_integer(nil), do: nil
  defp normalize_integer(value) when is_integer(value), do: value

  defp normalize_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp normalize_integer(_value), do: nil

  defp average([]), do: nil
  defp average(values), do: Float.round(Enum.sum(values) / length(values), 2)
  defp percentile([], _percentile), do: nil

  defp percentile(values, percentile) do
    index = values |> length() |> Kernel.-(1) |> Kernel.*(percentile) |> Float.ceil() |> trunc()
    Enum.at(values, index)
  end

  defp safe_ratio(_numerator, 0), do: 0.0
  defp safe_ratio(numerator, denominator), do: Float.round(numerator / denominator, 4)

  defp normalize_options(opts) when is_list(opts), do: Map.new(opts)

  defp normalize_options(opts) when is_map(opts) do
    Enum.reduce(opts, %{}, fn
      {key, value}, acc when is_atom(key) -> Map.put(acc, key, value)
      {"actions", value}, acc -> Map.put(acc, :actions, value)
      {"filter", value}, acc -> Map.put(acc, :filter, value)
      {"request_id_start", value}, acc -> Map.put(acc, :request_id_start, value)
      {"rate_limit", value}, acc -> Map.put(acc, :rate_limit, value)
      {"generated_at", value}, acc -> Map.put(acc, :generated_at, value)
      {"retention", value}, acc -> Map.put(acc, :retention, value)
      {"blocks", value}, acc -> Map.put(acc, :blocks, value)
      {"transactions", value}, acc -> Map.put(acc, :transactions, value)
      {"logs", value}, acc -> Map.put(acc, :logs, value)
      {"metrics", value}, acc -> Map.put(acc, :metrics, value)
      {"type", value}, acc -> Map.put(acc, :type, value)
      {"chain", value}, acc -> Map.put(acc, :chain, value)
      {"address", value}, acc -> Map.put(acc, :address, value)
      {"topic", value}, acc -> Map.put(acc, :topic, value)
      {"limit", value}, acc -> Map.put(acc, :limit, value)
      {"offset", value}, acc -> Map.put(acc, :offset, value)
      {_key, _value}, acc -> acc
    end)
  end

  defp normalize_options(_opts), do: %{}

  defp maybe_put(map, _key, value) when value in [nil, [], %{}], do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp fetch_value(map, key) when is_map(map) and is_atom(key) do
    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, Atom.to_string(key)) -> Map.get(map, Atom.to_string(key))
      true -> nil
    end
  end

  defp drop_empty_values(map) do
    Map.reject(map, fn {_key, value} -> value in [nil, [], %{}] end)
  end

  defp utc_now do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end
end
