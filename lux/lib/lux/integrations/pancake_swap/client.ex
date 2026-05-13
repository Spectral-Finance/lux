defmodule Lux.Integrations.PancakeSwap.Client do
  @moduledoc """
  GraphQL client helpers for PancakeSwap subgraph-backed workflows.
  """

  alias Lux.Integrations.PancakeSwap

  @type opts :: keyword() | map()
  @type request_result :: {:ok, term()} | {:error, term()}

  @farm_pools_query """
  query PancakeSwapFarmPools($first: Int!) {
    pools(first: $first) {
      id
      pid
      allocPoint
      totalLiquidity
      totalBoostLiquidity
      token0 { id symbol decimals }
      token1 { id symbol decimals }
      fee
    }
  }
  """

  @positions_query """
  query PancakeSwapPositions($owner: Bytes!, $first: Int!) {
    userPositionInfos(where: { user: $owner }, first: $first) {
      id
      pid
      liquidity
      boostLiquidity
      tickLower
      tickUpper
      reward
      user
    }
  }
  """

  @doc "Fetches MasterChef V3 farm pools for a chain."
  @spec farm_pools(atom() | String.t() | integer(), opts()) :: request_result()
  def farm_pools(chain, opts \\ %{}) do
    opts = put_variable(opts, :first, opt(normalize_opts(opts), :first, 50))
    query(chain, :masterchef_v3, @farm_pools_query, opts)
  end

  @doc "Fetches MasterChef V3 positions for an owner."
  @spec positions(atom() | String.t() | integer(), String.t(), opts()) :: request_result()
  def positions(chain, owner, opts \\ %{}) do
    opts =
      opts
      |> put_variable(:owner, String.downcase(owner))
      |> put_variable(:first, opt(normalize_opts(opts), :first, 50))

    query(chain, :masterchef_v3, @positions_query, opts)
  end

  @doc "Runs a GraphQL query against a configured PancakeSwap subgraph endpoint."
  @spec query(atom() | String.t() | integer(), atom() | String.t(), String.t(), opts()) ::
          request_result()
  def query(chain, graph, graph_query, opts \\ %{}) do
    opts = normalize_opts(opts)

    with {:ok, url} <- PancakeSwap.subgraph_endpoint(chain, graph, opts) do
      request(url, graph_query, opt(opts, :variables, %{}), opts)
    end
  end

  defp request(url, graph_query, variables, opts) do
    [
      method: :post,
      url: url,
      headers: headers(opts),
      json: %{query: graph_query, variables: variables},
      retry: opt(opts, :retry, false)
    ]
    |> maybe_add_plug(opt(opts, :plug))
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  defp handle_response({:ok, %{status: status, body: %{"errors" => _errors} = body}})
       when status in 200..299,
       do: {:error, PancakeSwap.classify_error(400, body)}

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299,
    do: {:ok, body}

  defp handle_response({:ok, %{status: status, body: body}}),
    do: {:error, PancakeSwap.classify_error(status, body)}

  defp handle_response({:error, error}), do: {:error, error}

  defp headers(opts) do
    [{"Accept", "application/json"}, {"Content-Type", "application/json"}] ++
      opt(opts, :headers, [])
  end

  defp put_variable(opts, key, value) do
    opts = normalize_opts(opts)
    variables = opt(opts, :variables, %{}) |> Map.put(to_string(key), value)
    Map.put(opts, :variables, variables)
  end

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)

  defp normalize_opts(opts) when is_map(opts), do: opts
  defp normalize_opts(opts) when is_list(opts), do: Map.new(opts)
  defp normalize_opts(nil), do: %{}

  defp opt(opts, key, default \\ nil) do
    cond do
      Map.has_key?(opts, key) -> Map.fetch!(opts, key)
      Map.has_key?(opts, to_string(key)) -> Map.fetch!(opts, to_string(key))
      true -> default
    end
  end
end
