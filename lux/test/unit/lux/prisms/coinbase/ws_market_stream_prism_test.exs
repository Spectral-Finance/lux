defmodule Lux.Prisms.Coinbase.WSMarketStreamPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Coinbase.WSMarketStreamPrism

  describe "view/0" do
    test "returns valid prism struct" do
      prism = WSMarketStreamPrism.view()

      assert prism.name == "Coinbase WebSocket Market Stream"
      assert prism.input_schema.required == ["action"]
    end

    test "action enum includes all operations" do
      prism = WSMarketStreamPrism.view()
      actions = prism.input_schema.properties.action.enum

      assert "subscribe" in actions
      assert "unsubscribe" in actions
      assert "subscribe_all" in actions
      assert "get_subscriptions" in actions
      assert "get_status" in actions
    end

    test "channels enum includes all supported channels" do
      prism = WSMarketStreamPrism.view()
      props = prism.input_schema.properties.channels

      assert props.type == :array
      expected = [
        "heartbeats", "candles", "market_trades", "status", "ticker",
        "ticker_batch", "level2", "user", "futures_balance_summary"
      ]

      for ch <- expected do
        assert ch in props.enum
      end
    end

    test "output schema defines success and channels" do
      prism = WSMarketStreamPrism.view()
      props = prism.output_schema.properties

      assert Map.has_key?(props, :success)
      assert Map.has_key?(props, :channels)
      assert Map.has_key?(props, :product_ids)
      assert Map.has_key?(props, :subscriptions)
    end
  end

  describe "handler/2" do
    test "get_status action" do
      result = WSMarketStreamPrism.handler(%{action: "get_status"}, nil)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "subscribe requires channels and product_ids" do
      result =
        WSMarketStreamPrism.handler(%{
          action: "subscribe",
          channels: ["ticker"],
          product_ids: ["BTC-USD"]
        }, nil)

      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "unsubscribe requires channels and product_ids" do
      result =
        WSMarketStreamPrism.handler(%{
          action: "unsubscribe",
          channels: ["ticker"],
          product_ids: ["BTC-USD"]
        }, nil)

      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end
  end
end
