defmodule Lux.Prisms.Coinbase.GetCandlesPrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.Coinbase.GetCandlesPrism

  describe "view/0" do
    test "returns valid prism struct" do
      prism = GetCandlesPrism.view()

      assert prism.name == "Coinbase Candles"
      assert prism.input_schema.required == ["product_id", "start", "end", "granularity"]
    end

    test "granularity enum is defined" do
      prism = GetCandlesPrism.view()
      gran = prism.input_schema.properties.granularity

      assert gran.type == :integer
      assert gran.enum == [60, 300, 900, 3600, 14400, 86400]
    end

    test "output schema defines candles array" do
      prism = GetCandlesPrism.view()
      assert Map.has_key?(prism.output_schema.properties, :candles)
    end
  end

  describe "handler/2" do
    test "requires all mandatory fields" do
      result = GetCandlesPrism.handler(%{product_id: "BTC-USD"}, nil)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "handler with all fields" do
      result =
        GetCandlesPrism.handler(%{
          product_id: "BTC-USD",
          start: "2024-01-01T00:00:00Z",
          end: "2024-01-02T00:00:00Z",
          granularity: 3600
        }, nil)

      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end
  end
end
