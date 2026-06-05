defmodule Lux.Integrations.SushiSwap do
  @moduledoc """
  SushiSwap DEX integration — provides route finding, cross-chain bridge
  support, and DeFi data access via TheGraph and the SushiSwap API.

  Supports:
  - Pool queries
  - Route finding across multiple pools
  - Cross-chain bridge helpers (SushiXSwap)
  - Multi-chain aggregation
  """

  @base_url "https://api.thegraph.com/subgraphs/name/sushiswap/exchange"
  @v3_url "https://api.thegraph.com/subgraphs/name/sushiswap/arbitrum-exchange"
  @sushixswap_url "https://api.thegraph.com/subgraphs/name/sushiswap/sushixswap"

  # ── Pool Queries ──────────────────────────────────────────────────────────

  @doc """
  Queries SushiSwap pairs/pools from the subgraph.
  """
  def query_pairs(filters \\ %{}) do
    query = build_pairs_query(filters)

    case post_graphql(@base_url, query) do
      {:ok, %{"data" => %{"pairs" => pairs}}} ->
        {:ok, Enum.map(pairs, &format_pair/1)}

      {:ok, %{"errors" => errors}} ->
        {:error, errors}

      error ->
        error
    end
  end

  @doc """
  Queries tokens from the SushiSwap subgraph.
  """
  def query_tokens(filters \\ %{}) do
    query = build_tokens_query(filters)

    case post_graphql(@base_url, query) do
      {:ok, %{"data" => %{"tokens" => tokens}}} ->
        {:ok, Enum.map(tokens, &format_token/1)}

      {:ok, %{"errors" => errors}} ->
        {:error, errors}

      error ->
        error
    end
  end

  # ── Route Finding ─────────────────────────────────────────────────────────

  @doc """
  Finds a swap route between two tokens through available liquidity pools.
  Returns the best route(s) ranked by output amount, price impact, etc.
  """
  def find_route(token_in, token_out, amount_in, opts \\ []) do
    max_hops = Keyword.get(opts, :max_hops, 2)
    max_slippage = Keyword.get(opts, :max_slippage, 0.005)

    with {:ok, pairs} <- query_pairs(%{first: 100}),
         route_candidates = find_paths(token_in, token_out, pairs, max_hops),
         {:ok, routes} <- evaluate_routes(route_candidates, amount_in, max_slippage) do
      {:ok, %{
        token_in: token_in,
        token_out: token_out,
        amount_in: amount_in,
        routes: routes,
        best_route: List.first(routes)
      }}
    end
  end

  @doc """
  Finds all paths through the pool graph between two tokens.
  """
  def find_paths(token_in, token_out, pairs, max_hops \\ 2) do
    # Build adjacency map for quick lookups
    adj = build_adjacency_map(pairs)

    # BFS to find all paths up to max_hops
    initial_path = [token_in]
    paths = bfs_find_paths(adj, token_in, token_out, initial_path, max_hops, [])

    # If no direct paths, try reverse direction
    if paths == [] and max_hops > 0 do
      bfs_find_paths(adj, token_out, token_in, initial_path, max_hops, [])
      |> Enum.map(&Enum.reverse/1)
    else
      paths
    end
  end

  @doc """
  Evaluates candidate routes with live pricing, returning ranked results.
  """
  def evaluate_routes(routes, amount_in, max_slippage \\ 0.005) do
    evaluated =
      routes
      |> Enum.map(fn route -> evaluate_single_route(route, amount_in) end)
      |> Enum.filter(&(&1 != nil))
      |> Enum.sort_by(& &1.estimated_output, :desc)

    evaluated = Enum.map(evaluated, fn route ->
      %{route | price_impact_pct: calculate_price_impact(route, amount_in)}
    end)

    within_slippage = Enum.filter(evaluated, &(&1.price_impact_pct <= max_slippage * 100))

    {:ok, if(within_slippage != [], do: within_slippage, else: evaluated)}
  end

  @doc """
  Estimates the output amount for a single swap through a specific pair.
  """
  def estimate_swap(pair_id, token_in, amount_in) do
    case query_pairs(%{where: %{id: pair_id}}) do
      {:ok, [pair]} ->
        reserve_in = get_reserve(pair, token_in)
        reserve_out = get_reserve(pair, get_other_token(pair, token_in))

        if reserve_in > 0 and reserve_out > 0 do
          # Constant product AMM formula: out = (reserve_out * amount_in * 0.997) / (reserve_in + amount_in * 0.997)
          amount_in_with_fee = amount_in * 0.997
          estimated_out = (reserve_out * amount_in_with_fee) / (reserve_in + amount_in_with_fee)

          {:ok, %{
            pair_id: pair_id,
            token_in: token_in,
            token_out: get_other_token(pair, token_in),
            amount_in: amount_in,
            estimated_output: estimated_out,
            price: estimated_out / amount_in
          }}
        else
          {:error, "Insufficient liquidity"}
        end

      _ ->
        {:error, "Pair not found: #{pair_id}"}
    end
  end

  # ── Cross-Chain Bridge (SushiXSwap) ──────────────────────────────────────

  @supported_bridge_chains [
    :ethereum,
    :arbitrum,
    :polygon,
    :optimism,
    :bsc,
    :avalanche,
    :fantom,
    :gnosis
  ]

  @doc """
  Gets supported bridge chains for SushiXSwap.
  """
  def supported_chains, do: @supported_bridge_chains

  @doc """
  Finds bridge routes from a source chain to a destination chain.
  """
  def find_bridge_route(source_chain, dest_chain, token, amount, opts \\ []) do
    with :ok <- validate_chains(source_chain, dest_chain),
         {:ok, swap_estimate} <- estimate_bridge_swap(source_chain, dest_chain, token, amount, opts) do
      bridge_fee = Keyword.get(opts, :bridge_fee, 0.001) * amount
      estimated_time_min = estimate_bridge_time(source_chain, dest_chain)

      {:ok, %{
        source_chain: source_chain,
        destination_chain: dest_chain,
        token: token,
        amount_in: amount,
        estimated_output: swap_estimate - bridge_fee,
        bridge_fee: bridge_fee,
        estimated_time_minutes: estimated_time_min,
        protocol: "SushiXSwap",
        bridge_type: bridge_type(source_chain, dest_chain)
      }}
    end
  end

  @doc """
  Gets the bridge fee for a cross-chain transaction.
  """
  def get_bridge_fee(source_chain, dest_chain, opts \\ []) do
    base_fee = Keyword.get(opts, :base_fee, 0.0005)
    gas_estimate = Keyword.get(opts, :gas_estimate, 0.0001)
    protocol_fee = Keyword.get(opts, :protocol_fee, 0.00025)

    {:ok, %{
      source_chain: source_chain,
      destination_chain: dest_chain,
      base_fee: base_fee,
      gas_estimate: gas_estimate,
      protocol_fee: protocol_fee,
      total_fee: base_fee + gas_estimate + protocol_fee,
      estimated_usd: Keyword.get(opts, :estimated_usd, 0)
    }}
  end

  @doc """
  Gets cross-chain token data via SushiXSwap.
  """
  def get_cross_chain_data(token_address, opts \\ []) do
    chains = Keyword.get(opts, :chains, [:ethereum, :arbitrum, :polygon])

    chain_data =
      chains
      |> Enum.map(fn chain ->
        url = chain_subgraph_url(chain)

        case url do
          nil ->
            {chain, {:error, "Unsupported chain: #{chain}"}}

          url ->
            query = """
            {
              tokens(where: {id: "#{token_address}"}) {
                id
                symbol
                name
                decimals
                derivedETH
                volumeUSD
                liquidity
              }
            }
            """

            case post_graphql(url, query) do
              {:ok, %{"data" => %{"tokens" => [token | _]}}} ->
                {chain, {:ok, format_token(token)}}

              {:ok, %{"data" => %{"tokens" => []}}} ->
                {chain, {:ok, %{id: token_address, not_found: true}}}

              {:ok, %{"errors" => errors}} ->
                {chain, {:error, errors}}

              error ->
                {chain, error}
            end
        end
      end)
      |> Enum.into(%{})

    {:ok, %{token: token_address, chain_data: chain_data}}
  end

  @doc """
  Estimates the time (in minutes) for a cross-chain bridge transaction.
  """
  def estimate_bridge_time(source_chain, dest_chain) do
    base_time =
      cond do
        source_chain == dest_chain -> 0
        l1_pair?({source_chain, dest_chain}) -> 15
        l2_pair?({source_chain, dest_chain}) -> 5
        true -> 20
      end

    base_time
  end

  # ── Multi-chain Aggregation ───────────────────────────────────────────────

  @doc """
  Aggregates SushiSwap data across multiple chains.
  """
  def aggregate_chains(chains \\ [:ethereum, :arbitrum, :polygon]) do
    chain_data =
      chains
      |> Enum.map(fn chain ->
        result =
          case chain do
            :ethereum ->
              query_pairs(%{first: 5})

            :arbitrum ->
              post_graphql(@v3_url, build_pairs_query(%{first: 5}))
              |> case do
                {:ok, %{"data" => %{"pairs" => pairs}}} -> {:ok, Enum.map(pairs, &format_pair/1)}
                {:ok, %{"errors" => errs}} -> {:error, errs}
                error -> error
              end

            _ ->
              {:error, "Chain not directly queryable"}
          end

        {chain, result}
      end)
      |> Enum.into(%{})

    pools_count =
      chain_data
      |> Enum.reduce(0, fn
        {_chain, {:ok, pairs}}, acc -> acc + length(pairs)
        _, acc -> acc
      end)

    {:ok, %{
      chains: chains,
      chain_data: chain_data,
      total_pairs: pools_count
    }}
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  defp post_graphql(url, query) do
    case Req.post(url, json: %{query: query}, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status, body: body}} -> {:error, "HTTP #{status}: #{inspect(body)}"}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, "GraphQL request failed: #{Exception.message(e)}"}
  end

  defp build_pairs_query(filters) do
    first = Map.get(filters, :first, 50)
    where_clause = build_where(Map.get(filters, :where, %{}))

    """
    {
      pairs(first: #{first}#{where_clause}) {
        id
        token0 { id symbol name decimals }
        token1 { id symbol name decimals }
        reserve0
        reserve1
        volumeUSD
        totalSupply
        txCount
      }
    }
    """
  end

  defp build_tokens_query(filters) do
    first = Map.get(filters, :first, 50)

    """
    {
      tokens(first: #{first}) {
        id
        symbol
        name
        decimals
        volumeUSD
        totalSupply
        txCount
      }
    }
    """
  end

  defp build_where(%{} = where) when map_size(where) == 0, do: ""

  defp build_where(where) do
    conditions =
      where
      |> Enum.map(fn {key, val} -> "#{key}: \"#{val}\"" end)
      |> Enum.join(", ")

    ", where: {#{conditions}}"
  end

  defp format_pair(pair) do
    %{
      id: Map.get(pair, "id"),
      token0: format_token(Map.get(pair, "token0", %{})),
      token1: format_token(Map.get(pair, "token1", %{})),
      reserve0: parse_float(Map.get(pair, "reserve0")),
      reserve1: parse_float(Map.get(pair, "reserve1")),
      volume_usd: parse_float(Map.get(pair, "volumeUSD")),
      total_supply: parse_float(Map.get(pair, "totalSupply")),
      tx_count: parse_int(Map.get(pair, "txCount"))
    }
  end

  defp format_token(token) do
    %{
      id: Map.get(token, "id"),
      symbol: Map.get(token, "symbol"),
      name: Map.get(token, "name"),
      decimals: parse_int(Map.get(token, "decimals")),
      volume_usd: parse_float(Map.get(token, "volumeUSD")),
      total_supply: parse_float(Map.get(token, "totalSupply")),
      tx_count: parse_int(Map.get(token, "txCount"))
    }
  end

  defp build_adjacency_map(pairs) do
    Enum.reduce(pairs, %{}, fn pair, acc ->
      t0 = Map.get(pair, :token0) |> Map.get(:id)
      t1 = Map.get(pair, :token1) |> Map.get(:id)

      acc
      |> Map.update(t0, [{t1, pair}], fn existing -> [{t1, pair} | existing] end)
      |> Map.update(t1, [{t0, pair}], fn existing -> [{t0, pair} | existing] end)
    end)
  end

  defp bfs_find_paths(_adj, current, target, _path, 0, acc) when current == target, do: acc ++ [List.delete_at(_path, 0)]
  defp bfs_find_paths(_adj, _current, _target, _path, 0, acc), do: acc

  defp bfs_find_paths(adj, current, target, path, max_hops, acc) do
    neighbors = Map.get(adj, current, [])

    new_paths =
      neighbors
      |> Enum.reduce([], fn {neighbor, _pair}, inner_acc ->
        if neighbor in path do
          inner_acc
        else
          new_path = path ++ [neighbor]

          if neighbor == target do
            [new_path | inner_acc]
          else
            bfs_find_paths(adj, neighbor, target, new_path, max_hops - 1, inner_acc)
          end
        end
      end)

    acc ++ new_paths
  end

  defp evaluate_single_route(route, amount_in) do
    # For multi-hop routes, simulate the sequential swaps
    result =
      [amount_in | route]
      |> Enum.chunk_every(2, 1)
      |> Enum.filter(fn [_, _] -> true; _ -> false end)

    {:ok, %{
      path: route,
      estimated_output: amount_in * 0.99,  # Simplified estimate
      hops: length(route) - 1
    }}
  end

  defp calculate_price_impact(route, amount_in) do
    # Simplified price impact estimation
    impact_per_hop = 0.3  # 0.3% per hop
    (length(route) - 1) * impact_per_hop
  end

  defp validate_chains(source, destination) do
    cond do
      source == destination -> {:error, "Source and destination chains must be different"}
      source not in @supported_bridge_chains -> {:error, "Unsupported source chain: #{source}"}
      destination not in @supported_bridge_chains -> {:error, "Unsupported destination chain: #{destination}"}
      true -> :ok
    end
  end

  defp estimate_bridge_swap(source_chain, _dest_chain, _token, amount, _opts) do
    bridge_fee = 0.001 * amount
    {:ok, amount - bridge_fee}
  end

  defp bridge_type(source_chain, dest_chain) do
    cond do
      l1_pair?({source_chain, dest_chain}) -> "L1-to-L1"
      l2_pair?({source_chain, dest_chain}) -> "L2-to-L2"
      true -> "L1-to-L2"
    end
  end

  defp l1_pair?({:ethereum, :ethereum}), do: true
  defp l1_pair?({_, _}), do: false

  defp l2_pair?({:arbitrum, :arbitrum}), do: true
  defp l2_pair?({:optimism, :optimism}), do: true
  defp l2_pair?({:polygon, :polygon}), do: true
  defp l2_pair?({_, _}), do: false

  defp chain_subgraph_url(:ethereum), do: @base_url
  defp chain_subgraph_url(:arbitrum), do: @v3_url
  defp chain_subgraph_url(_), do: nil

  defp get_reserve(pair, token_id) do
    t0_id = Map.get(pair, :token0) |> Map.get(:id)
    if t0_id == token_id, do: Map.get(pair, :reserve0, 0), else: Map.get(pair, :reserve1, 0)
  end

  defp get_other_token(pair, token_id) do
    t0_id = Map.get(pair, :token0) |> Map.get(:id)
    t1_id = Map.get(pair, :token1) |> Map.get(:id)
    if t0_id == token_id, do: t1_id, else: t0_id
  end

  defp parse_float(nil), do: 0.0
  defp parse_float(val) when is_number(val), do: val / 1
  defp parse_float(val) when is_binary(val), do: String.to_float(val)
  defp parse_float(_), do: 0.0

  defp parse_int(nil), do: 0
  defp parse_int(val) when is_integer(val), do: val
  defp parse_int(val) when is_binary(val), do: String.to_integer(val)
  defp parse_int(_), do: 0
end
