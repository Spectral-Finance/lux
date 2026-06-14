defmodule Lux.Prisms.Hyperliquid.HyperliquidUserStatePrismTest do
  use UnitCase, async: true

  import Mock

  alias Lux.Prisms.Hyperliquid.HyperliquidUserStatePrism

  @test_address "0x0403369c02199a0cb827f4d6492927e9fa5668d5"

  describe "handler/2" do
    test "fetches user state successfully" do
      with_mock Lux.Python, [eval!: fn _, _ -> %{
        "assetPositions" => [],
        "crossMarginSummary" => %{"accountValue" => "10000.0"}
      } end] do
        {:ok, result} = HyperliquidUserStatePrism.run(%{address: @test_address})
        assert result.status == "success"
        assert is_map(result.user_state)
      end
    end

    test "handles missing private key" do
      with_mock Lux.Config, [hyperliquid_account_key: fn -> raise RuntimeError, "missing" end] do
        {:error, error} = HyperliquidUserStatePrism.run(%{address: @test_address})
        assert String.contains?(error, "private key")
      end
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = HyperliquidUserStatePrism.view()
      assert prism.input_schema.required == ["address"]
      assert Map.has_key?(prism.input_schema.properties, :address)
    end

    test "validates output schema" do
      prism = HyperliquidUserStatePrism.view()
      assert prism.output_schema.required == ["status", "user_state"]
    end
  end
end
