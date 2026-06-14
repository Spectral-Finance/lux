defmodule Lux.Prisms.Pancakeswap.PancakeswapFarmPrismTest do
  use UnitCase, async: true
  import Mock
  alias Lux.Prisms.Pancakeswap.PancakeswapFarmPrism

  describe "handler/2" do
    test "stakes in farm successfully" do
      with_mock Lux.Python, [eval!: fn _, _ -> %{
        "tx_hash" => "0xabc123",
        "status" => "success",
        "staked_amount" => "100.0",
        "apy" => "25.5"
      } end] do
        {:ok, result} = PancakeswapFarmPrism.run(%{
          farm_address: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
          amount: "100.0",
          action: "stake"
        })
        assert result.status == "success"
      end
    end

    test "harvests rewards successfully" do
      with_mock Lux.Python, [eval!: fn _, _ -> %{
        "tx_hash" => "0xdef456",
        "status" => "success",
        "reward_amount" => "5.0"
      } end] do
        {:ok, result} = PancakeswapFarmPrism.run(%{
          farm_address: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56",
          amount: "0",
          action: "harvest"
        })
        assert result.status == "success"
      end
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = PancakeswapFarmPrism.view()
      assert "farm_address" in prism.input_schema.required
    end
  end
end