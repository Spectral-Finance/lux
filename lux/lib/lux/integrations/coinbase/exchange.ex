defmodule Lux.Integrations.Coinbase.Exchange do
  @moduledoc """
  Coinbase Advanced Trade request-planning helpers.

  This module builds deterministic REST and WebSocket plans without storing API
  keys, signing JWTs, or sending live orders. It gives prisms, lenses, and
  client adapters a safe integration core for market data, order management,
  account snapshots, and rate-limit accounting.
  """

  @rest_base "https://api.coinbase.com"
  @ws_base "wss://advanced-trade-ws.coinbase.com"
  @api_host "api.coinbase.com"

  @public_endpoints %{
    products: {:get, "/api/v3/brokerage/products", 1},
    product: {:get, "/api/v3/brokerage/products/:product_id", 1},
    product_book: {:get, "/api/v3/brokerage/product_book", 2},
    best_bid_ask: {:get, "/api/v3/brokerage/best_bid_ask", 1},
    market_trades: {:get, "/api/v3/brokerage/products/:product_id/ticker", 2},
    candles: {:get, "/api/v3/brokerage/products/:product_id/candles", 3}
  }

  @signed_endpoints %{
    accounts: {:get, "/api/v3/brokerage/accounts", 2},
    account: {:get, "/api/v3/brokerage/accounts/:account_uuid", 1},
    portfolios: {:get, "/api/v3/brokerage/portfolios", 2},
    orders: {:get, "/api/v3/brokerage/orders/historical/batch", 2},
    order: {:get, "/api/v3/brokerage/orders/historical/:order_id", 1},
    fills: {:get, "/api/v3/brokerage/orders/historical/fills", 2},
    create_order: {:post, "/api/v3/brokerage/orders", 1},
    cancel_orders: {:post, "/api/v3/brokerage/orders/batch_cancel", 1}
  }

  @doc """
  Builds a public REST request plan.
  """
  @spec public_request(atom(), map()) :: {:ok, map()} | {:error, String.t()}
  def public_request(request, attrs \\ %{}) do
    with {:ok, method, template, weight} <- endpoint(@public_endpoints, request, "public"),
         {:ok, path} <- interpolate_path(template, attrs),
         {:ok, params} <- public_params(request, attrs) do
      {:ok,
       %{
         request: request,
         method: method,
         base_url: @rest_base,
         path: path,
         url: @rest_base <> path,
         params: params,
         weight: weight,
         security_type: :none
       }}
    end
  end

  @doc """
  Builds a signed REST request plan and the JWT claims to sign elsewhere.
  """
  @spec signed_request(atom(), map()) :: {:ok, map()} | {:error, String.t()}
  def signed_request(action, attrs \\ %{}) do
    with {:ok, method, template, weight} <- endpoint(@signed_endpoints, action, "signed"),
         {:ok, path} <- interpolate_path(template, attrs),
         {:ok, params, body} <- signed_payload(action, attrs) do
      claims = jwt_claims(method, path, attrs)

      {:ok,
       %{
         action: action,
         method: method,
         base_url: @rest_base,
         path: path,
         url: @rest_base <> path,
         params: params,
         body: body,
         jwt_claims: claims,
         headers: auth_headers(attrs),
         weight: weight,
         security_type: :jwt
       }}
    end
  end

  @doc """
  Normalizes Coinbase order input into an Advanced Trade order configuration.
  """
  @spec order_plan(map()) :: {:ok, map()} | {:error, String.t()}
  def order_plan(attrs) when is_map(attrs) do
    product_id = normalize_product_id(value(attrs, :product_id) || value(attrs, :symbol))
    side = normalize_side(value(attrs, :side))
    type = normalize_order_type(value(attrs, :type) || value(attrs, :order_type))

    cond do
      product_id == "" ->
        {:error, "Missing Coinbase product_id"}

      is_nil(side) ->
        {:error, "Unsupported Coinbase order side"}

      is_nil(type) ->
        {:error, "Unsupported Coinbase order type"}

      true ->
        build_order(product_id, side, type, attrs)
    end
  end

  @doc """
  Builds a WebSocket subscription plan.
  """
  @spec websocket_subscription([String.t() | atom()], [String.t()], map()) ::
          {:ok, map()} | {:error, String.t()}
  def websocket_subscription(channels, product_ids, attrs \\ %{})
      when is_list(channels) and is_list(product_ids) do
    normalized_channels = channels |> Enum.map(&normalize_channel/1) |> Enum.reject(&(&1 == ""))
    normalized_products = product_ids |> Enum.map(&normalize_product_id/1) |> Enum.reject(&(&1 == ""))

    cond do
      normalized_channels == [] ->
        {:error, "At least one Coinbase WebSocket channel is required"}

      normalized_products == [] ->
        {:error, "At least one Coinbase product_id is required"}

      true ->
        {:ok,
         %{
           base_url: @ws_base,
           url: @ws_base,
           type: "subscribe",
           product_ids: normalized_products,
           channel_names: normalized_channels,
           jwt: value(attrs, :jwt),
           message: reject_nil_values(%{
             type: "subscribe",
             product_ids: normalized_products,
             channel_names: normalized_channels,
             jwt: value(attrs, :jwt)
           })
         }}
    end
  end

  @doc """
  Estimates Coinbase request-budget usage for planned requests.
  """
  @spec rate_limit_summary([map()], map()) :: map()
  def rate_limit_summary(requests, policy \\ %{}) do
    limit = value(policy, :limit_per_second) || 30
    used = requests |> Enum.map(&(value(&1, :weight) || 1)) |> Enum.sum()

    %{
      request_count: length(requests),
      used_weight: used,
      limit_per_second: limit,
      remaining_weight: max(limit - used, 0),
      allowed?: used <= limit,
      utilization: ratio(used, limit)
    }
  end

  @doc """
  Summarizes account balances and portfolio holdings.
  """
  @spec portfolio_snapshot(map()) :: map()
  def portfolio_snapshot(attrs) when is_map(attrs) do
    accounts = attrs |> value(:accounts) |> List.wrap() |> Enum.map(&account_snapshot/1)
    portfolios = attrs |> value(:portfolios) |> List.wrap() |> Enum.map(&portfolio_entry/1)

    %{
      accounts: accounts,
      portfolios: portfolios,
      total_available: accounts |> Enum.map(& &1.available_balance) |> Enum.sum() |> round_float(),
      total_hold: accounts |> Enum.map(& &1.hold_balance) |> Enum.sum() |> round_float(),
      asset_count: accounts |> Enum.map(& &1.currency) |> Enum.uniq() |> length()
    }
  end

  defp endpoint(endpoints, action, label) do
    case Map.fetch(endpoints, action) do
      {:ok, {method, path, weight}} -> {:ok, method, path, weight}
      :error -> {:error, "Unsupported Coinbase #{label} request: #{action}"}
    end
  end

  defp public_params(:products, attrs), do: {:ok, only_present(attrs, [:limit, :offset, :product_type])}
  defp public_params(:product, _attrs), do: {:ok, %{}}
  defp public_params(:market_trades, attrs), do: {:ok, only_present(attrs, [:limit])}

  defp public_params(:product_book, attrs) do
    if present?(value(attrs, :product_id) || value(attrs, :symbol)) do
      {:ok, only_present(attrs, [:product_id, :limit]) |> normalize_product_param(attrs)}
    else
      {:error, "Coinbase product_book requires product_id"}
    end
  end

  defp public_params(:best_bid_ask, attrs), do: {:ok, product_ids_param(attrs)}

  defp public_params(:candles, attrs) do
    required = [:start, :end, :granularity]

    if Enum.all?(required, &present?(value(attrs, &1))) do
      {:ok, only_present(attrs, required)}
    else
      {:error, "Coinbase candles require start, end, and granularity"}
    end
  end

  defp signed_payload(:create_order, attrs) do
    with {:ok, order} <- order_plan(attrs) do
      {:ok, %{},
       %{
         client_order_id: value(attrs, :client_order_id) || generated_client_order_id(attrs),
         product_id: order.product_id,
         side: order.side,
         order_configuration: order.order_configuration
       }}
    end
  end

  defp signed_payload(:cancel_orders, attrs) do
    order_ids = (value(attrs, :order_ids) || value(attrs, :order_id)) |> List.wrap()

    if order_ids == [] do
      {:error, "Coinbase cancel_orders requires order_ids"}
    else
      {:ok, %{}, %{order_ids: Enum.map(order_ids, &string/1)}}
    end
  end

  defp signed_payload(_action, attrs) do
    {:ok, only_present(attrs, [:limit, :cursor, :product_id, :order_status, :start_date, :end_date]), %{}}
  end

  defp build_order(product_id, side, "MARKET", attrs) do
    base_size = value(attrs, :base_size) || value(attrs, :quantity)
    quote_size = value(attrs, :quote_size) || value(attrs, :funds)

    cond do
      present?(base_size) ->
        {:ok,
         %{
           product_id: product_id,
           side: side,
           type: "MARKET",
           order_configuration: %{market_market_ioc: %{base_size: decimal_string(base_size)}}
         }}

      present?(quote_size) ->
        {:ok,
         %{
           product_id: product_id,
           side: side,
           type: "MARKET",
           order_configuration: %{market_market_ioc: %{quote_size: decimal_string(quote_size)}}
         }}

      true ->
        {:error, "Coinbase market orders require base_size or quote_size"}
    end
  end

  defp build_order(product_id, side, "LIMIT", attrs) do
    base_size = value(attrs, :base_size) || value(attrs, :quantity)
    price = value(attrs, :limit_price) || value(attrs, :price)

    if present?(base_size) and present?(price) do
      {:ok,
       %{
         product_id: product_id,
         side: side,
         type: "LIMIT",
         order_configuration: %{
           limit_limit_gtc: %{
             base_size: decimal_string(base_size),
             limit_price: decimal_string(price),
             post_only: !!value(attrs, :post_only)
           }
         }
       }}
    else
      {:error, "Coinbase limit orders require base_size and limit_price"}
    end
  end

  defp build_order(_product_id, _side, type, _attrs), do: {:error, "Unsupported Coinbase order type: #{type}"}

  defp jwt_claims(method, path, attrs) do
    issued_at = value(attrs, :issued_at) || 0
    expires_in = value(attrs, :expires_in) || 120

    %{
      iss: "cdp",
      sub: value(attrs, :api_key_name),
      aud: @api_host,
      uri: "#{method |> Atom.to_string() |> String.upcase()} #{@api_host}#{path}",
      iat: issued_at,
      exp: issued_at + expires_in
    }
    |> reject_nil_values()
  end

  defp auth_headers(attrs) do
    case value(attrs, :jwt) do
      nil -> []
      jwt -> [{"Authorization", "Bearer #{jwt}"}]
    end
  end

  defp interpolate_path(template, attrs) do
    product_id = normalize_product_id(value(attrs, :product_id) || value(attrs, :symbol))
    account_uuid = value(attrs, :account_uuid)
    order_id = value(attrs, :order_id)

    cond do
      String.contains?(template, ":product_id") and product_id == "" ->
        {:error, "Coinbase request requires product_id"}

      String.contains?(template, ":account_uuid") and not present?(account_uuid) ->
        {:error, "Coinbase request requires account_uuid"}

      String.contains?(template, ":order_id") and not present?(order_id) ->
        {:error, "Coinbase request requires order_id"}

      true ->
        {:ok,
         template
         |> String.replace(":product_id", product_id)
         |> String.replace(":account_uuid", string(account_uuid))
         |> String.replace(":order_id", string(order_id))}
    end
  end

  defp account_snapshot(attrs) when is_map(attrs) do
    available = value(attrs, :available_balance) || value(attrs, :available)
    hold = value(attrs, :hold_balance) || value(attrs, :hold)

    %{
      uuid: optional_string(value(attrs, :uuid)),
      name: optional_string(value(attrs, :name)),
      currency: string(value(attrs, :currency)) |> String.upcase(),
      available_balance: balance_value(available),
      hold_balance: balance_value(hold),
      default?: !!value(attrs, :default)
    }
  end

  defp account_snapshot(_attrs) do
    %{uuid: nil, name: nil, currency: "", available_balance: 0.0, hold_balance: 0.0, default?: false}
  end

  defp portfolio_entry(attrs) when is_map(attrs) do
    %{
      uuid: optional_string(value(attrs, :uuid)),
      name: optional_string(value(attrs, :name)),
      type: optional_string(value(attrs, :type)),
      deleted?: !!value(attrs, :deleted)
    }
  end

  defp portfolio_entry(_attrs), do: %{uuid: nil, name: nil, type: nil, deleted?: false}

  defp balance_value(%{value: value}), do: number(value)
  defp balance_value(%{"value" => value}), do: number(value)
  defp balance_value(value), do: number(value)

  defp normalize_product_param(params, attrs) do
    product_id = normalize_product_id(value(attrs, :product_id) || value(attrs, :symbol))
    Map.put(params, :product_id, product_id)
  end

  defp product_ids_param(attrs) do
    product_ids =
      attrs
      |> value(:product_ids)
      |> List.wrap()
      |> Enum.map(&normalize_product_id/1)
      |> Enum.reject(&(&1 == ""))

    if product_ids == [], do: %{}, else: %{product_ids: Enum.join(product_ids, ",")}
  end

  defp only_present(attrs, keys) do
    keys
    |> Enum.reduce(%{}, fn key, acc ->
      case value(attrs, key) do
        value when value in [nil, ""] -> acc
        value -> Map.put(acc, key, value)
      end
    end)
  end

  defp reject_nil_values(map) do
    Map.reject(map, fn {_key, value} -> is_nil(value) or value == %{} or value == [] end)
  end

  defp generated_client_order_id(attrs) do
    case value(attrs, :now_ms) do
      nil -> "lux-coinbase-order"
      value -> string(value)
    end
  end

  defp normalize_side(value) do
    case value |> string() |> String.upcase() do
      "BUY" -> "BUY"
      "SELL" -> "SELL"
      _ -> nil
    end
  end

  defp normalize_order_type(value) do
    case value |> string() |> String.upcase() do
      "MARKET" -> "MARKET"
      "LIMIT" -> "LIMIT"
      _ -> nil
    end
  end

  defp normalize_channel(value) do
    value
    |> string()
    |> String.downcase()
    |> String.replace("-", "_")
  end

  defp normalize_product_id(nil), do: ""

  defp normalize_product_id(value) do
    value
    |> string()
    |> String.upcase()
    |> String.replace("_", "-")
  end

  defp decimal_string(value) do
    value
    |> number()
    |> :erlang.float_to_binary(decimals: 8)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
  end

  defp ratio(_used, 0), do: 0.0
  defp ratio(used, limit), do: Float.round(used / limit, 6)

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?([]), do: false
  defp present?(_value), do: true

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, Atom.to_string(key))
  defp value(_map, _key), do: nil

  defp optional_string(nil), do: nil
  defp optional_string(""), do: nil
  defp optional_string(value), do: string(value)

  defp string(nil), do: ""
  defp string(value) when is_binary(value), do: value
  defp string(value) when is_atom(value), do: Atom.to_string(value)
  defp string(value), do: to_string(value)

  defp number(nil), do: 0.0
  defp number(value) when is_integer(value), do: value * 1.0
  defp number(value) when is_float(value), do: value

  defp number(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _rest} -> number
      :error -> 0.0
    end
  end

  defp number(_value), do: 0.0

  defp round_float(value), do: Float.round(number(value), 6)
end
