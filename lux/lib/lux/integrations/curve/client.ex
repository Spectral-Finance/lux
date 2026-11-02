defmodule Lux.Integrations.Curve.Client do
  @moduledoc """
  HTTP and Web3 RPC Client for Curve Finance protocol interactions,
  stablecoin pool analytics, and gauge staking telemetry.
  """

  require Logger

  @curve_api_endpoint "https://api.curve.fi/api"
  @default_network "ethereum"

  @type request_opts :: %{
    optional(:network) => String.t(),
    optional(:params) => map(),
    optional(:plug) => {module(), term()}
  }

  @doc """
  Makes an API request to Curve Finance endpoints or custom plugs during tests.
  """
  @spec get_pool_data(String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def get_pool_data(pool_id, opts \\ %{}) do
    network = Map.get(opts, :network, @default_network)
    url = "#{@curve_api_endpoint}/getPools/#{network}/#{pool_id}"

    case request(:get, url, opts) do
      {:ok, %{"data" => data}} -> {:ok, data}
      {:ok, data} when is_map(data) -> {:ok, data}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetches all liquidity gauges and weight data for CRV emission optimization.
  """
  @spec get_gauge_data(request_opts()) :: {:ok, map()} | {:error, term()}
  def get_gauge_data(opts \\ %{}) do
    url = "#{@curve_api_endpoint}/getAllGauges"
    request(:get, url, opts)
  end

  @doc """
  Performs generic HTTP requests with plug injection for isolated unit testing.
  """
  def request(method, url, opts \\ %{}) do
    req_opts = [
      method: method,
      url: url,
      headers: [{"accept", "application/json"}, {"user-agent", "Lux-Agent-Curve-Client/1.0"}]
    ]

    req_opts =
      if plug = Map.get(opts, :plug) do
        Keyword.put(req_opts, :plug, plug)
      else
        req_opts
      end

    case Req.request(req_opts) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("Curve API Error [HTTP #{status}]: #{inspect(body)}")
        {:error, %{status: status, body: body}}

      {:error, reason} ->
        Logger.error("Curve API Network Failure: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
