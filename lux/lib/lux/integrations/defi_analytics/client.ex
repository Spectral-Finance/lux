defmodule Lux.Integrations.DeFiAnalytics.Client do
  @moduledoc """
  DeFiLlama and Dune API request helpers for protocol analytics workflows.
  """

  alias Lux.Integrations.DeFiAnalytics

  @type opts :: keyword() | map()
  @type request_result :: {:ok, term()} | {:error, term()}

  @doc "Fetches all DeFiLlama protocols."
  @spec protocols(opts()) :: request_result()
  def protocols(opts \\ %{}), do: request(:defillama, :get, "/protocols", opts)

  @doc "Fetches current and historical TVL for a DeFiLlama protocol slug."
  @spec protocol(String.t(), opts()) :: request_result()
  def protocol(slug, opts \\ %{}), do: request(:defillama, :get, "/protocol/#{slug}", opts)

  @doc "Fetches historical TVL chart data."
  @spec historical_tvl(opts()) :: request_result()
  def historical_tvl(opts \\ %{}), do: request(:defillama, :get, "/v2/historicalChainTvl", opts)

  @doc "Fetches DeFiLlama yield pools."
  @spec yield_pools(opts()) :: request_result()
  def yield_pools(opts \\ %{}), do: request(:yields, :get, "/pools", opts)

  @doc "Fetches DeFiLlama DEX volume overview data."
  @spec dex_volume_overview(opts()) :: request_result()
  def dex_volume_overview(opts \\ %{}), do: request(:defillama, :get, "/overview/dexs", opts)

  @doc "Fetches DeFiLlama DEX volume overview data for one chain."
  @spec dex_volume_overview_for_chain(String.t(), opts()) :: request_result()
  def dex_volume_overview_for_chain(chain, opts \\ %{}) do
    request(:defillama, :get, "/overview/dexs/#{chain}", opts)
  end

  @doc "Fetches DeFiLlama DEX volume history for one protocol."
  @spec dex_volume_summary(String.t(), opts()) :: request_result()
  def dex_volume_summary(protocol, opts \\ %{}) do
    request(:defillama, :get, "/summary/dexs/#{protocol}", opts)
  end

  @doc "Fetches latest Dune query result without triggering execution."
  @spec dune_latest_result(String.t() | integer(), opts()) :: request_result()
  def dune_latest_result(query_id, opts \\ %{}) do
    request(:dune, :get, "/query/#{query_id}/results", opts)
  end

  @doc "Executes an existing Dune query."
  @spec dune_execute_query(String.t() | integer(), opts()) :: request_result()
  def dune_execute_query(query_id, opts \\ %{}) do
    request(:dune, :post, "/query/#{query_id}/execute", opts)
  end

  @doc "Executes ad-hoc SQL through Dune."
  @spec dune_execute_sql(String.t(), opts()) :: request_result()
  def dune_execute_sql(sql, opts \\ %{}) do
    opts =
      put_json(
        opts,
        %{sql: sql, performance: opt(normalize_opts(opts), :performance)} |> drop_nil()
      )

    request(:dune, :post, "/sql/execute", opts)
  end

  @doc "Fetches Dune execution results."
  @spec dune_execution_result(String.t(), opts()) :: request_result()
  def dune_execution_result(execution_id, opts \\ %{}) do
    request(:dune, :get, "/execution/#{execution_id}/results", opts)
  end

  @doc "Fetches Dune execution status."
  @spec dune_execution_status(String.t(), opts()) :: request_result()
  def dune_execution_status(execution_id, opts \\ %{}) do
    request(:dune, :get, "/execution/#{execution_id}/status", opts)
  end

  @doc "Makes a raw DeFi analytics request."
  @spec request(:defillama | :yields | :dune, atom(), String.t(), opts()) :: request_result()
  def request(api, method, path, opts \\ %{}) do
    opts = normalize_opts(opts)

    [
      method: method,
      url: base_url(api, opts) <> path,
      headers: headers(api, opts),
      params: opt(opts, :params, %{}) |> drop_nil(),
      json: opt(opts, :json),
      retry: opt(opts, :retry, false)
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opt(opts, :plug))
    |> drop_nil_keyword()
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  defp handle_response({:ok, %{status: status, body: body}}) when status in 200..299,
    do: {:ok, body}

  defp handle_response({:ok, %{status: status, body: body}}),
    do: {:error, DeFiAnalytics.classify_error(status, body)}

  defp handle_response({:error, error}), do: {:error, error}

  defp base_url(:defillama, opts), do: opt(opts, :base_url, DeFiAnalytics.defillama_base_url())
  defp base_url(:yields, opts), do: opt(opts, :base_url, DeFiAnalytics.defillama_yields_url())
  defp base_url(:dune, opts), do: opt(opts, :base_url, DeFiAnalytics.dune_base_url())

  defp headers(:dune, opts) do
    api_key = opt(opts, :api_key, DeFiAnalytics.dune_api_key())
    base = [{"Accept", "application/json"}, {"Content-Type", "application/json"}]

    if is_binary(api_key) and api_key != "" do
      [{"x-dune-api-key", api_key} | base]
    else
      base
    end
  end

  defp headers(_api, _opts), do: [{"Accept", "application/json"}]

  defp put_json(opts, json), do: opts |> normalize_opts() |> Map.put(:json, json)

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

  defp drop_nil(map), do: Map.reject(map, fn {_key, value} -> is_nil(value) end)
  defp drop_nil_keyword(keyword), do: Enum.reject(keyword, fn {_key, value} -> is_nil(value) end)
end
