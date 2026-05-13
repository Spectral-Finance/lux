defmodule Lux.Integrations.SushiSwap.Client do
  @moduledoc """
  Req-based SushiSwap REST API client.
  """

  alias Lux.Integrations.SushiSwap

  @type request_opts :: %{
          optional(:base_url) => String.t(),
          optional(:referrer) => String.t(),
          optional(:headers) => [{String.t(), String.t()}],
          optional(:plug) => {module(), term()}
        }

  @doc "Gets a SushiSwap quote for a chain."
  @spec quote(atom() | String.t() | integer(), map(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  def quote(chain, params, opts \\ %{}) do
    request(:get, "/quote/v7/#{chain_id!(chain)}", params_with_referrer(params, opts), opts)
  end

  @doc "Gets executable swap transaction data for a chain."
  @spec swap(atom() | String.t() | integer(), map(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  def swap(chain, params, opts \\ %{}) do
    request(:get, "/swap/v7/#{chain_id!(chain)}", params_with_referrer(params, opts), opts)
  end

  @doc "Gets token prices for a chain."
  @spec prices(atom() | String.t() | integer(), request_opts()) :: {:ok, map()} | {:error, term()}
  def prices(chain, opts \\ %{}) do
    request(:get, "/price/v1/#{chain_id!(chain)}", %{}, opts)
  end

  @doc "Gets token metadata for a chain."
  @spec token(atom() | String.t() | integer(), String.t(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  def token(chain, token_address, opts \\ %{}) do
    request(:get, "/token/v1/#{chain_id!(chain)}/#{String.downcase(token_address)}", %{}, opts)
  end

  @doc "Gets pool metadata when the Sushi API has the pool endpoint enabled."
  @spec pool(atom() | String.t() | integer(), String.t(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  def pool(chain, pool_address, opts \\ %{}) do
    request(:get, "/pool/v1/#{chain_id!(chain)}/#{String.downcase(pool_address)}", %{}, opts)
  end

  defp request(method, path, query, opts) do
    settings = SushiSwap.client_settings()
    base_url = option(opts, :base_url, settings.base_url)
    headers = settings.headers ++ option(opts, :headers, [])

    [
      method: method,
      url: base_url <> path,
      headers: headers,
      params: encode_query(query)
    ]
    |> maybe_add_plug(option(opts, :plug))
    |> Req.new()
    |> Req.request()
    |> normalize_response()
  end

  defp normalize_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp normalize_response({:ok, %{status: status, body: %{"title" => title, "errors" => errors}}}) do
    {:error, {status, title, errors}}
  end

  defp normalize_response({:ok, %{status: status, body: body}}), do: {:error, {status, body}}
  defp normalize_response({:error, error}), do: {:error, error}

  defp params_with_referrer(params, opts) do
    params
    |> opts_map()
    |> Map.put_new(:referrer, option(opts, :referrer, SushiSwap.client_settings().referrer))
  end

  defp encode_query(params) do
    params
    |> opts_map()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new(fn {key, value} -> {to_string(key), encode_value(value)} end)
  end

  defp encode_value(value) when is_atom(value), do: Atom.to_string(value)
  defp encode_value(value) when is_integer(value), do: Integer.to_string(value)
  defp encode_value(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 8)
  defp encode_value(value), do: value

  defp chain_id!(chain) do
    case SushiSwap.chain_id(chain) do
      nil -> raise ArgumentError, "unsupported SushiSwap chain: #{inspect(chain)}"
      id -> id
    end
  end

  defp opts_map(opts) when is_map(opts), do: opts
  defp opts_map(opts) when is_list(opts), do: Map.new(opts)

  defp option(opts, key, default \\ nil)
  defp option(opts, key, default) when is_map(opts), do: Map.get(opts, key, default)
  defp option(opts, key, default) when is_list(opts), do: Keyword.get(opts, key, default)

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)
end
