defmodule Lux.Prisms.Hyperliquid.HyperliquidPnlPrismTest do
  use UnitCase, async: true
  import Mock
  alias Lux.Prisms.Hyperliquid.HyperliquidPnlPrism

  @test_address "0x0403369c02199a0cb827f4d6492927e9fa5668d5"

  describe "handler/2" do
    test "fetches pnl data successfully" do
      with_mock Lux.Python, [run_python: fn _, _ ->
        {:ok, %{
          "total_unrealized_pnl" => "100.0",
          "total_realized_pnl" => "0",
          "positions" => [],
          "recent_fills" => []
        }}
      end] do
        {:ok, result} = HyperliquidPnlPrism.run(%{address: @test_address})
        assert result.status == "success"
        assert is_map(result.pnl_data)
      end
    end

    test "handles missing private key" do
      with_mock Lux.Config, [hyperliquid_account_key: fn -> raise RuntimeError, "missing" end] do
        {:error, error} = HyperliquidPnlPrism.run(%{address: @test_address})
        assert String.contains?(error, "private key")
      end
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = HyperliquidPnlPrism.view()
      assert prism.input_schema.required == ["address"]
    end

    test "validates output schema" do
      prism = HyperliquidPnlPrism.view()
      assert prism.output_schema.required == ["status", "pnl_data"]
    end
  end
end