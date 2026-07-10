defmodule Lux.Lenses.DefiLlama.GetProtocolTvlTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.DefiLlama.GetProtocolTvl

  describe "after_focus/1" do
    test "returns scalar TVL when response is a number" do
      assert {:ok, 16_437_632_965.43} = GetProtocolTvl.after_focus(16_437_632_965.43)
    end

    test "returns metadata map when response contains name" do
      response = %{"name" => "Lido", "symbol" => "LDO", "tvl" => [%{}]}
      assert {:ok, ^response} = GetProtocolTvl.after_focus(response)
    end

    test "returns error when response contains message" do
      assert {:error, "Protocol not found"} =
               GetProtocolTvl.after_focus(%{"message" => "Protocol not found"})
    end

    test "returns error for unexpected response" do
      assert {:error, "Invalid response from DeFiLlama: " <> _} =
               GetProtocolTvl.after_focus(%{"unexpected" => true})
    end
  end

  describe "focus/2 input validation" do
    test "returns error when protocol is missing" do
      assert {:error, "Missing required parameter: protocol"} = GetProtocolTvl.focus(%{})
    end
  end
end
