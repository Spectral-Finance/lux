defmodule Lux.Lenses.Coinbase.MarketData do
  @moduledoc """
  Lenses for Coinbase market data: products, ticker, orderbook, candles.
  """

  alias Lux.Integrations.Coinbase.Client

  @spec get_products(map()) :: {:ok, list(map())} | {:error, term()}
  def get_products(opts \\ %{}) do
    case Client.request(:get, "/products", opts) do
      {:ok, %{"products" => products}} -> {:ok, Enum.map(products, &format_product/1)}
      {:error, error} -> {:error, error}
    end
  end

  @spec get_ticker(String.t(), map()) :: {:ok, map()} | {:error, term()}
  def get_ticker(product_id, opts \\ %{}) do
    case Client.request(:get, "/products/#{product_id}", opts) do
      {:ok, product} -> {:ok, format_product(product)}
      {:error, error} -> {:error, error}
    end
  end

  @spec get_candles(String.t(), map(), map()) :: {:ok, list(map())} | {:error, term()}
  def get_candles(product_id, params, opts \\ %{}) do
    case Client.request(:get, "/products/#{product_id}/candles", Map.put(opts, :params, params)) do
      {:ok, %{"candles" => candles}} -> {:ok, Enum.map(candles, &format_candle/1)}
      {:error, error} -> {:error, error}
    end
  end

  @spec get_orderbook(String.t(), map(), map()) :: {:ok, map()} | {:error, term()}
  def get_orderbook(product_id, params \\ %{}, opts \\ %{}) do
    merged = Map.put(opts, :params, Map.put(params, :product_id, product_id))
    case Client.request(:get, "/product_book", merged) do
      {:ok, %{"pricebook" => pb}} -> {:ok, format_orderbook(pb)}
      {:error, error} -> {:error, error}
    end
  end

  defp format_product(p) do
    %{
      product_id: p["product_id"],
      price: p["price"],
      price_percentage_change_24h: p["price_percentage_change_24h"],
      volume_24h: p["volume_24h"],
      base_currency_id: p["base_currency_id"],
      quote_currency_id: p["quote_currency_id"],
      status: p["status"]
    }
  end

  defp format_candle(c) do
    %{start: c["start"], open: c["open"], high: c["high"], low: c["low"], close: c["close"], volume: c["volume"]}
  end

  defp format_orderbook(pb) do
    %{
      product_id: pb["product_id"],
      bids: Enum.map(pb["bids"] || [], fn b -> %{price: b["price"], size: b["size"]} end),
      asks: Enum.map(pb["asks"] || [], fn a -> %{price: a["price"], size: a["size"]} end),
      time: pb["time"]
    }
  end
end
