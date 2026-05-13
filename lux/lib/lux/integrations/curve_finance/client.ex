defmodule Lux.Integrations.CurveFinance.Client do
  @moduledoc """
  Req-based client for Curve Finance's public API.
  """

  alias Lux.Integrations.CurveFinance

  @type request_opts :: %{
          optional(:base_url) => String.t(),
          optional(:headers) => [{String.t(), String.t()}],
          optional(:plug) => {module(), term()}
        }

  @doc "Makes a raw GET request to Curve's public API."
  @spec get(String.t(), request_opts()) :: {:ok, term()} | {:error, term()}
  def get(path, opts \\ %{}) do
    settings = CurveFinance.client_settings()
    base_url = option(opts, :base_url, settings.base_url)
    headers = settings.headers ++ option(opts, :headers, [])

    [
      method: :get,
      url: base_url <> path,
      headers: headers
    ]
    |> maybe_add_plug(option(opts, :plug))
    |> Req.new()
    |> Req.request()
    |> normalize_response()
  end

  @doc "Fetches Curve deployment platforms and registries."
  @spec platforms(request_opts()) :: {:ok, map()} | {:error, term()}
  def platforms(opts \\ %{}), do: get("/getPlatforms", opts)

  @doc "Fetches pool addresses for a chain."
  @spec pool_list(atom() | String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def pool_list(chain, opts \\ %{}) do
    get("/getPoolList/#{CurveFinance.chain_id(chain)}", opts)
  end

  @doc "Fetches all Curve pools for one chain."
  @spec pools(atom() | String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def pools(chain, opts \\ %{}) do
    get("/getPools/all/#{CurveFinance.chain_id(chain)}", opts)
  end

  @doc "Fetches Curve pools from one registry on one chain."
  @spec registry_pools(atom() | String.t(), atom() | String.t(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  def registry_pools(chain, registry, opts \\ %{}) do
    get("/getPools/#{CurveFinance.chain_id(chain)}/#{CurveFinance.registry_id(registry)}", opts)
  end

  @doc "Fetches all Curve gauges across chains and registries."
  @spec gauges(request_opts()) :: {:ok, map()} | {:error, term()}
  def gauges(opts \\ %{}), do: get("/getAllGauges", opts)

  @doc "Fetches 24h volume and base APY data for a chain."
  @spec volumes(atom() | String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def volumes(chain, opts \\ %{}) do
    get("/getVolumes/#{CurveFinance.chain_id(chain)}", opts)
  end

  @doc "Fetches base APY data for a chain."
  @spec base_apys(atom() | String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def base_apys(chain, opts \\ %{}) do
    get("/getBaseApys/#{CurveFinance.chain_id(chain)}", opts)
  end

  defp normalize_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp normalize_response({:ok, %{status: status, body: %{"error" => error}}}) do
    {:error, {status, error}}
  end

  defp normalize_response({:ok, %{status: status, body: body}}), do: {:error, {status, body}}
  defp normalize_response({:error, error}), do: {:error, error}

  defp option(opts, key, default \\ nil)
  defp option(opts, key, default) when is_map(opts), do: Map.get(opts, key, default)
  defp option(opts, key, default) when is_list(opts), do: Keyword.get(opts, key, default)

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
