defmodule Lux.Integrations.Coinbase.OrderManager do
  @moduledoc """
  Coinbase Advanced Trade v3 order placement and management engine:
  - Supports Limit (GTC, GTD), Market, and Stop-Limit order configurations
  - Generates unique client order IDs (idempotency keys)
  - Manages order cancellation requests
  """

  @valid_sides ["BUY", "SELL"]
  @valid_types ["LIMIT", "MARKET", "STOP_LIMIT"]

  @doc """
  Generates a random UUIDv4 string for client order idempotency.
  """
  @spec generate_client_order_id() :: String.t()
  def generate_client_order_id do
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)
    bin = <<u0::48, 4::4, u1::12, 2::2, u2::62>>
    <<a::32, b::16, c::16, d::16, e::48>> = bin

    :io_lib.format("~8.16.0b-~4.16.0b-~4.16.0b-~4.16.0b-~12.16.0b", [a, b, c, d, e])
    |> IO.iodata_to_binary()
  end

  @doc """
  Builds order creation payload for `/api/v3/brokerage/orders`.
  """
  @spec build_order(map()) :: {:ok, map()} | {:error, String.t()}
  def build_order(params) do
    product_id = Map.get(params, :product_id) || Map.get(params, "product_id")
    side = (Map.get(params, :side) || Map.get(params, "side", "")) |> String.upcase()
    order_type = (Map.get(params, :type) || Map.get(params, "type", "LIMIT")) |> String.upcase()
    base_size = Map.get(params, :base_size) || Map.get(params, "base_size")
    quote_size = Map.get(params, :quote_size) || Map.get(params, "quote_size")
    limit_price = Map.get(params, :limit_price) || Map.get(params, "limit_price")
    stop_price = Map.get(params, :stop_price) || Map.get(params, "stop_price")
    client_id = Map.get(params, :client_order_id) || Map.get(params, "client_order_id") || generate_client_order_id()

    cond do
      is_nil(product_id) or product_id == "" ->
        {:error, "product_id is required (e.g. BTC-USD)"}

      side not in @valid_sides ->
        {:error, "Invalid side: #{side}. Must be BUY or SELL"}

      order_type not in @valid_types ->
        {:error, "Invalid order type: #{order_type}"}

      order_type == "LIMIT" and (is_nil(base_size) or is_nil(limit_price)) ->
        {:error, "base_size and limit_price are required for LIMIT orders"}

      order_type == "MARKET" and is_nil(base_size) and is_nil(quote_size) ->
        {:error, "Either base_size or quote_size is required for MARKET orders"}

      order_type == "STOP_LIMIT" and (is_nil(base_size) or is_nil(limit_price) or is_nil(stop_price)) ->
        {:error, "base_size, limit_price, and stop_price are required for STOP_LIMIT orders"}

      true ->
        order_config =
          case order_type do
            "LIMIT" ->
              %{
                "limit_limit_gtc" => %{
                  "base_size" => to_string(base_size),
                  "limit_price" => to_string(limit_price),
                  "post_only" => Map.get(params, :post_only, false)
                }
              }

            "MARKET" ->
              market_cfg =
                if base_size,
                  do: %{"base_size" => to_string(base_size)},
                  else: %{"quote_size" => to_string(quote_size)}

              %{"market_market_ioc" => market_cfg}

            "STOP_LIMIT" ->
              stop_direction = if side == "BUY", do: "STOP_DIRECTION_STOP_UP", else: "STOP_DIRECTION_STOP_DOWN"

              %{
                "stop_limit_stop_limit_gtc" => %{
                  "base_size" => to_string(base_size),
                  "limit_price" => to_string(limit_price),
                  "stop_price" => to_string(stop_price),
                  "stop_direction" => stop_direction
                }
              }
          end

        payload = %{
          "client_order_id" => client_id,
          "product_id" => String.upcase(product_id),
          "side" => side,
          "order_configuration" => order_config
        }

        {:ok, payload}
    end
  end

  @doc """
  Builds order cancellation payload for `/api/v3/brokerage/orders/batch_cancel`.
  """
  @spec build_cancel_order(list(String.t())) :: {:ok, map()} | {:error, String.t()}
  def build_cancel_order(order_ids) when is_list(order_ids) and length(order_ids) > 0 do
    {:ok, %{"order_ids" => order_ids}}
  end

  def build_cancel_order(_), do: {:error, "At least one order_id must be provided"}
end
