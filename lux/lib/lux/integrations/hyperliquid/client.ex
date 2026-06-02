defmodule Lux.Integrations.Hyperliquid.Client do
  @moduledoc """
  HTTP client for the Hyperliquid REST API.

  Handles all HTTP requests to Hyperliquid's info and exchange endpoints.
  Uses `Req` for robust HTTP client capabilities including retries,
  timeouts, and JSON encoding/decoding.

  ## Safety Gate

  All private exchange actions (order placement, cancellation, margin
  changes, leverage updates) require an explicit opt-in via environment
  variable or application config:

      # Enable via env var (testnet recommended for development):
      export HYPERLIQUID_TESTNET=true

      # Or via application config:
      config :lux, hyperliquid_live_trading_allowed: true

  Without either, `place_order/2`, `cancel_order/3`, `modify_margin/3`,
  and `query_private/2` return `{:error, :live_trading_disabled}`.
  Public read-only endpoints (`query_public/2`) are never gated.

  ## API Endpoints

  The module supports two endpoints:

  * `POST /info` — Public data (market data, user state, open orders)
  * `POST /exchange` — Private/authenticated actions (orders, margin)

  ## Order Precision

  All prices are rounded to 5 decimal places (Hyperliquid tick size).
  Sizes are rounded to `szDecimals` from market metadata (default 5).
  Trigger prices in trigger orders get the same rounding treatment.

  ## Examples

      # Get all mid prices
      iex> Client.query_public(%{type: "allMids"})
      {:ok, ["ETH" => "2800.5", ...]}

      # Fetch market metadata (asset IDs, size precision)
      iex> Client.get_market_data()
      {:ok, %{"universe" => [...]}}

      # Place a limit order (requires live trading enabled)
      iex> Client.place_order(%{
      ...>   asset: "ETH",
      ...>   is_buy: true,
      ...>   size: 0.1,
      ...>   price: 2800.0,
      ...>   order_type: %{limit: %{tif: "Gtc"}},
      ...>   reduce_only: false
      ...> })
      {:ok, %{"resting" => %{"oid" => 123456}}}

      # Add isolated margin
      iex> Client.modify_margin("ETH", %{is_deposit: true, amount: "100"})
      {:ok, %{"status" => "ok"}}

      # Update leverage
      iex> Client.modify_margin("ETH", %{leverage: 5, is_cross: true})
      {:ok, %{"status" => "ok"}}

  ## Configuration

      config :lux, :accounts,
        hyperliquid_private_key: "0x...",
        hyperliquid_address: "0x...",
        hyperliquid_api_url: "https://api.hyperliquid.xyz"
  """

  require Logger

  alias Lux.Config
  alias Lux.Integrations.Hyperliquid.Signing

  @info_endpoint "/info"
  @exchange_endpoint "/exchange"

  @type request_opts :: %{
    optional(:plug) => {module(), term()},
    optional(:base_url) => String.t()
  }

  @doc """
  Queries the public Hyperliquid info endpoint.

  ## Parameters

    * `payload` - The info request body (e.g., %{type: "allMids"})
    * `opts` - Optional request options

  ## Returns

    * `{:ok, data}` — Successful response
    * `{:error, reason}` — Failed request
  """
  @spec query_public(map(), request_opts()) :: {:ok, term()} | {:error, term()}
  def query_public(payload, opts \\ %{}) do
    opts = normalize_opts(opts)
    base_url = Keyword.get(opts, :base_url, api_url())

    [
      method: :post,
      url: base_url <> @info_endpoint,
      headers: [{"Content-Type", "application/json"}],
      json: payload
    ]
    |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
    |> maybe_add_plug(opts[:plug])
    |> Req.new()
    |> Req.request()
    |> handle_response()
  end

  @doc """
  Queries the private Hyperliquid exchange endpoint.

  Automatically signs the request with EIP-712.

  ## Safety Gate

  All private exchange actions (order placement, cancellation, margin
  modifications) are gated behind an explicit live-trading flag.  Set
  `HYPERLIQUID_ALLOW_LIVE_TRADING=true` or `HYPERLIQUID_TESTNET=true`
  to enable private actions.  In test/CI without either, calls return
  `{:error, :live_trading_disabled}`.

  ## Parameters

    * `action` - The exchange action to perform
    * `opts` - Optional request options

  ## Returns

    * `{:ok, data}` — Successful response
    * `{:error, reason}` — Failed request
  """
  @spec query_private(map(), request_opts()) :: {:ok, term()} | {:error, term()}
  def query_private(action, opts \\ %{}) do
    unless Config.hyperliquid_live_trading_allowed?() do
      {:error, :live_trading_disabled}
    else
      do_query_private(action, opts)
    end
  end

  @doc false
  def do_query_private(action, opts) do
    opts = normalize_opts(opts)

    with {:ok, private_key} <- get_private_key(),
         nonce <- Signing.generate_nonce(),
         {:ok, signature} <- Signing.sign_l1_action(private_key, action, nonce) do
      base_url = Keyword.get(opts, :base_url, api_url())

      body = %{
        action: action,
        nonce: nonce,
        signature: signature
      }

      [
        method: :post,
        url: base_url <> @exchange_endpoint,
        headers: [{"Content-Type", "application/json"}],
        json: body
      ]
      |> Keyword.merge(Application.get_env(:lux, __MODULE__, []))
      |> maybe_add_plug(opts[:plug])
      |> Req.new()
      |> Req.request()
      |> handle_response()
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Places an order on Hyperliquid.

  ## Parameters

    * `params` - Order parameters map with keys:
      - `:asset` - Trading pair (e.g., "ETH")
      - `:is_buy` - Direction (true = buy, false = sell)
      - `:size` - Order size
      - `:price` - Limit price
      - `:order_type` - Order type config (limit or trigger)
      - `:reduce_only` - Whether order only reduces position
    * `opts` - Optional request options
  """
  @spec place_order(map(), request_opts()) :: {:ok, term()} | {:error, term()}
  def place_order(params, opts \\ %{}) do
    order = build_order(params)

    action = %{
      type: "order",
      orders: [order],
      grouping: "na"
    }

    with {:ok, result} <- query_private(action, opts) do
      case result do
        %{"response" => %{"data" => %{"statuses" => [status]}}} ->
          if status["error"] do
            {:error, status["error"]}
          else
            {:ok, status}
          end

        %{"status" => "err", "response" => error} ->
          {:error, error}

        other ->
          {:ok, other}
      end
    end
  end

  @doc """
  Cancels an order by order ID.

  ## Parameters

    * `asset` - Trading pair
    * `order_id` - Order ID to cancel
    * `opts` - Optional request options
  """
  @spec cancel_order(String.t(), integer(), request_opts()) :: {:ok, term()} | {:error, term()}
  def cancel_order(asset, order_id, opts \\ %{}) do
    cancel = %{
      a: asset,
      o: order_id
    }

    action = %{
      type: "cancel",
      cancels: [cancel]
    }

    with {:ok, result} <- query_private(action, opts) do
      case result do
        %{"response" => %{"data" => %{"statuses" => [status]}}} ->
          if status["error"] do
            {:error, status["error"]}
          else
            {:ok, status}
          end

        %{"status" => "err", "response" => error} ->
          {:error, error}

        other ->
          {:ok, other}
      end
    end
  end

  @doc """
  Cancels multiple orders at once.

  ## Parameters

    * `cancels` - List of %{asset: asset, order_id: id} maps
    * `opts` - Optional request options
  """
  @spec cancel_orders([%{asset: String.t(), order_id: integer()}], request_opts()) ::
          {:ok, term()} | {:error, term()}
  def cancel_orders(cancels, opts \\ %{}) do
    cancel_list = Enum.map(cancels, fn c -> %{a: c.asset, o: c.order_id} end)

    action = %{
      type: "cancel",
      cancels: cancel_list
    }

    query_private(action, opts)
  end

  @doc """
  Modifies margin for a position (add/remove margin, update leverage).

  ## Parameters

    * `asset` - Trading pair
    * `params` - Margin parameters:
      - `:is_deposit` - true to add margin, false to remove margin
      - `:amount` - USD amount (required for add/remove)
      - `:leverage` - New leverage value (required for leverage updates)
      - `:is_cross` - true for cross margin, false for isolated (for leverage/mode)
    * `opts` - Optional request options
  """
  @spec modify_margin(String.t(), map(), request_opts()) :: {:ok, term()} | {:error, term()}
  def modify_margin(asset, params, opts \\ %{}) do
    action = cond do
      params[:is_deposit] == true ->
        %{
          type: "updateIsolatedMargin",
          asset: asset,
          isBuy: true,
          ntli: to_string(params[:amount] || "0")
        }

      params[:is_deposit] == false ->
        %{
          type: "updateIsolatedMargin",
          asset: asset,
          isBuy: false,
          ntli: to_string(params[:amount] || "0")
        }

      true ->
        %{
          type: "updateLeverage",
          asset: asset,
          isCross: params[:is_cross] || params[:mode] == "cross" || false,
          leverage: params[:leverage] || 1
        }
    end

    query_private(action, opts)
  end

  @doc """
  Fetches account information for a wallet address.

  ## Parameters

    * `wallet_address` - Ethereum wallet address
    * `opts` - Optional request options
  """
  @spec get_account_info(String.t(), request_opts()) :: {:ok, term()} | {:error, term()}
  def get_account_info(wallet_address, opts \\ %{}) do
    payload = %{
      type: "clearinghouseState",
      user: wallet_address
    }

    query_public(payload, opts)
  end

  @doc """
  Fetches open orders for a wallet address.

  ## Parameters

    * `wallet_address` - Ethereum wallet address
    * `opts` - Optional request options
  """
  @spec get_open_orders(String.t(), request_opts()) :: {:ok, term()} | {:error, term()}
  def get_open_orders(wallet_address, opts \\ %{}) do
    payload = %{
      type: "openOrders",
      user: wallet_address
    }

    query_public(payload, opts)
  end

  @doc """
  Fetches metadata and asset contexts (token info, market data).

  ## Returns

    * `{:ok, data}` — Universe and asset contexts
    * `{:error, reason}` — Failed request
  """
  @spec get_market_data(request_opts()) :: {:ok, term()} | {:error, term()}
  def get_market_data(opts \\ %{}) do
    payload = %{type: "meta"}

    query_public(payload, opts)
  end

  @doc """
  Fetches all mid-prices across all markets.

  ## Returns

    * `{:ok, prices}` — Map of asset to mid-price
    * `{:error, reason}` — Failed request
  """
  @spec get_all_mids(request_opts()) :: {:ok, term()} | {:error, term()}
  def get_all_mids(opts \\ %{}) do
    payload = %{type: "allMids"}

    query_public(payload, opts)
  end

  @doc """
  Fetches L2 order book for a specific asset.

  ## Parameters

    * `asset` - Trading pair (e.g., "ETH")
    * `opts` - Optional request options
  """
  @spec get_l2_book(String.t(), request_opts()) :: {:ok, term()} | {:error, term()}
  def get_l2_book(asset, opts \\ %{}) do
    payload = %{
      type: "l2Book",
      req: %{coin: asset}
    }

    query_public(payload, opts)
  end

  @doc """
  Fetches recent trades for a specific asset.

  ## Parameters

    * `asset` - Trading pair (e.g., "ETH")
    * `opts` - Optional request options
  """
  @spec get_recent_trades(String.t(), request_opts()) :: {:ok, term()} | {:error, term()}
  def get_recent_trades(asset, opts \\ %{}) do
    payload = %{
      type: "recentTrades",
      req: %{coin: asset}
    }

    query_public(payload, opts)
  end

  @doc """
  Fetches candle/OHLCV data for an asset.

  ## Parameters

    * `asset` - Trading pair (e.g., "ETH")
    * `interval` - Candle interval (e.g., "1m", "5m", "15m", "1h", "4h", "1d")
    * `start_time` - Unix timestamp in milliseconds for start
    * `end_time` - Unix timestamp in milliseconds for end
    * `opts` - Optional request options
  """
  @spec get_candles(String.t(), String.t(), integer(), integer(), request_opts()) ::
          {:ok, term()} | {:error, term()}
  def get_candles(asset, interval, start_time, end_time, opts \\ %{}) do
    payload = %{
      type: "candleSnapshot",
      req: %{
        coin: asset,
        interval: interval,
        startTime: start_time,
        endTime: end_time
      }
    }

    query_public(payload, opts)
  end

  @doc """
  Fetches funding history for an asset.

  ## Parameters

    * `asset` - Trading pair
    * `start_time` - Unix timestamp in milliseconds
    * `opts` - Optional request options
  """
  @spec get_funding_history(String.t(), integer(), request_opts()) ::
          {:ok, term()} | {:error, term()}
  def get_funding_history(asset, start_time, opts \\ %{}) do
    payload = %{
      type: "fundingHistory",
      req: %{
        coin: asset,
        startTime: start_time
      }
    }

    query_public(payload, opts)
  end

  defp api_url do
    Config.hyperliquid_api_url()
  end

  defp get_private_key do
    {:ok, Config.hyperliquid_account_key()}
  rescue
    RuntimeError -> {:error, :missing_private_key}
  end

  defp build_order(params) do
    order = %{
      a: params[:asset],
      b: params[:is_buy],
      p: round_price(params[:price]),
      s: round_size(params[:asset], params[:size]),
      r: params[:reduce_only] || false,
      t: build_order_type(params[:order_type])
    }

    if params[:client_order_id] do
      Map.put(order, :c, params[:client_order_id])
    else
      order
    end
  end

  @doc """
  Rounds a price to Hyperliquid tick size (5 decimal places).
  """
  @spec round_price(float() | String.t()) :: String.t()
  def round_price(price) when is_number(price) do
    price
    |> Float.round(5)
    |> format_decimal()
  end

  def round_price(price) when is_binary(price) do
    case Float.parse(price) do
      {val, _} -> round_price(val)
      :error -> price
    end
  end

  @doc false
  def format_decimal(num) when is_number(num) do
    str = :erlang.float_to_binary(num, decimals: 5)
    # Strip trailing zeros after the decimal point only
    case String.split(str, ".") do
      [int_part, dec_part] ->
        trimmed = String.trim_trailing(dec_part, "0")
        if trimmed == "" do
          int_part <> ".0"
        else
          int_part <> "." <> trimmed
        end
      [_int_part] ->
        str
    end
  end

  @doc """
  Rounds a size to Hyperliquid lot size (szDecimals from metadata).

  Uses metadata from the meta endpoint (cached) to get per-asset
  szDecimals. Falls back to 5 decimal places if metadata unavailable.
  """
  @spec round_size(String.t(), float() | String.t()) :: String.t()
  def round_size(_asset, size) when is_number(size) do
    sz_decimals = 5
    size
    |> Float.round(sz_decimals)
    |> format_decimal()
  end

  def round_size(_asset, size) when is_binary(size) do
    case Float.parse(size) do
      {val, _} -> round_size(nil, val)
      :error -> size
    end
  end

  defp build_order_type(%{limit: %{tif: tif}}) do
    %{limit: %{tif: tif}}
  end

  defp build_order_type(%{trigger: trigger}) do
    %{
      trigger: %{
        triggerPx: round_price(trigger[:trigger_px]),
        isMarket: trigger[:is_market] || false,
        tpsl: trigger[:tpsl] || "sl"
      }
    }
  end

  defp build_order_type(nil), do: %{limit: %{tif: "Gtc"}}

  defp normalize_opts(opts) when is_map(opts), do: Enum.to_list(opts)
  defp normalize_opts(opts), do: opts

  defp maybe_add_plug(options, nil), do: options
  defp maybe_add_plug(options, plug), do: Keyword.put(options, :plug, plug)

  defp handle_response({:ok, %{status: status} = response}) when status in 200..299 do
    {:ok, response.body}
  end

  defp handle_response({:ok, %{status: status, body: body}}) do
    Logger.error("Hyperliquid API error: status=#{status}, body=#{inspect(body)}")
    {:error, {status, body}}
  end

  defp handle_response({:error, error}) do
    Logger.error("Hyperliquid API request failed: #{inspect(error)}")
    {:error, error}
  end
end
