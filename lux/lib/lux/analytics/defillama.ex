defmodule Lux.Analytics.DeFiLlama do
  @moduledoc """
  DeFiLlama integration for TVL, protocol metrics, and yield analytics.
  """

  require Logger

  @base_url "https://api.llama.fi"
  @http_timeout 30_000

  @doc """
  Fetches Total Value Locked (TVL) data for a specific protocol
  """
  def get_tvl(protocol_slug) do
    with {:ok, response} <- http_get("/protocol/#{protocol_slug}"),
         {:ok, data} <- decode_response(response) do
      {:ok, extract_tvl_data(data)}
    else
      error -> error
    end
  end

  @doc """
  Fetches protocol metrics including TVL, revenue, and user metrics
  """
  def get_protocol_metrics(protocol_slug) do
    with {:ok, response} <- http_get("/protocol/#{protocol_slug}"),
         {:ok, data} <- decode_response(response) do
      {:ok, extract_protocol_metrics(data)}
    else
      error -> error
    end
  end

  @doc """
  Fetches yield pools data
  """
  def get_yield_pools do
    with {:ok, response} <- http_get("/pools"),
         {:ok, data} <- decode_response(response) do
      {:ok, extract_yield_data(data)}
    else
      error -> error
    end
  end

  @doc """
  Fetches historical TVL data for a protocol
  """
  def get_historical_tvl(protocol_slug) do
    with {:ok, response} <- http_get("/charts/#{protocol_slug}"),
         {:ok, data} <- decode_response(response) do
      {:ok, data}
    else
      error -> error
    end
  end

  @doc """
  Search for protocols by name
  """
  def search_protocols(query) do
    with {:ok, response} <- http_get("/protocols"),
         {:ok, data} <- decode_response(response) do
      results = 
        data
        |> Enum.filter(fn protocol -> 
          String.contains?(String.downcase(protocol["name"] || ""), String.downcase(query))
        end)
        |> Enum.take(10)
      
      {:ok, results}
    else
      error -> error
    end
  end

  # Private functions

  defp http_get(path) do
    url = @base_url <> path
    
    case :httpc.request(:get, {String.to_charlist(url), []}, [], [timeout: @http_timeout]) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        {:ok, body}
      
      {:ok, {{_, status, _}, _headers, body}} ->
        {:error, "HTTP #{status}: #{body}"}
      
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, data} -> {:ok, data}
      {:error, reason} -> {:error, "JSON decode error: #{inspect(reason)}"}
    end
  end

  defp extract_tvl_data(data) do
    %{
      name: data["name"],
      tvl: data["tvl"] |> format_number(),
      change_1d: data["change_1d"],
      change_7d: data["change_7d"],
      change_1m: data["change_1m"]
    }
  end

  defp extract_protocol_metrics(data) do
    %{
      name: data["name"],
      tvl: data["tvl"] |> format_number(),
      chains: data["chains"] || [],
      category: data["category"],
      twitter: data["twitter"],
      symbol: data["symbol"]
    }
  end

  defp extract_yield_data(data) do
    data
    |> Enum.take(50)
    |> Enum.map(fn pool ->
      %{
        pool: pool["symbol"],
        project: pool["project"],
        chain: pool["chain"],
        apy: pool["apy"],
        tvl: pool["tvlUsd"] |> format_number()
      }
    end)
  end

  defp format_number(nil), do: 0
  defp format_number(num) when is_number(num), do: num
  defp format_number(_), do: 0
end