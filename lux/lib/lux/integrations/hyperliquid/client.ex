defmodule Lux.Integrations.Hyperliquid.Client do
  @moduledoc """
  Req-based Hyperliquid public info endpoint client.
  """

  alias Lux.Integrations.Hyperliquid

  @type request_opts :: %{
          optional(:base_url) => String.t(),
          optional(:headers) => [{String.t(), String.t()}],
          optional(:plug) => {module(), term()}
        }

  @doc "Calls Hyperliquid's `/info` endpoint with a raw payload."
  @spec info(map(), request_opts()) :: {:ok, term()} | {:error, term()}
  def info(payload, opts \\ %{}) when is_map(payload) do
    settings = Hyperliquid.client_settings()
    base_url = option(opts, :base_url, settings.base_url)
    headers = settings.headers ++ option(opts, :headers, [])

    [
      method: :post,
      url: base_url <> settings.info_endpoint,
      headers: headers,
      json: payload
    ]
    |> maybe_add_plug(option(opts, :plug))
    |> Req.new()
    |> Req.request()
    |> normalize_response()
  end

  @doc "Fetches perpetual universe metadata."
  @spec meta(request_opts()) :: {:ok, map()} | {:error, term()}
  def meta(opts \\ %{}), do: info(%{type: Hyperliquid.info_type(:meta)}, opts)

  @doc "Fetches all mid prices."
  @spec all_mids(request_opts()) :: {:ok, map()} | {:error, term()}
  def all_mids(opts \\ %{}), do: info(%{type: Hyperliquid.info_type(:all_mids)}, opts)

  @doc "Fetches an L2 order book snapshot for a perpetual coin."
  @spec l2_book(String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def l2_book(coin, opts \\ %{}) do
    info(%{type: Hyperliquid.info_type(:l2_book), coin: coin}, opts)
  end

  @doc "Fetches a user's perpetual clearinghouse state."
  @spec clearinghouse_state(String.t(), request_opts()) :: {:ok, map()} | {:error, term()}
  def clearinghouse_state(user, opts \\ %{}) do
    info(%{type: Hyperliquid.info_type(:clearinghouse_state), user: String.downcase(user)}, opts)
  end

  @doc "Fetches open orders for a user."
  @spec open_orders(String.t(), request_opts()) :: {:ok, list()} | {:error, term()}
  def open_orders(user, opts \\ %{}) do
    info(%{type: Hyperliquid.info_type(:open_orders), user: String.downcase(user)}, opts)
  end

  @doc "Fetches order status by order id or client order id."
  @spec order_status(String.t(), integer() | String.t(), request_opts()) ::
          {:ok, map()} | {:error, term()}
  def order_status(user, oid, opts \\ %{}) do
    info(
      %{type: Hyperliquid.info_type(:order_status), user: String.downcase(user), oid: oid},
      opts
    )
  end

  @doc "Fetches recent user fills."
  @spec user_fills(String.t(), request_opts()) :: {:ok, list()} | {:error, term()}
  def user_fills(user, opts \\ %{}) do
    info(%{type: Hyperliquid.info_type(:user_fills), user: String.downcase(user)}, opts)
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
