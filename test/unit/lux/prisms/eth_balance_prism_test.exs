defmodule Lux.Prisms.EthBalancePrismTest do
  use UnitCase, async: true

  alias Lux.Prisms.EthBalancePrism

  @test_address "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

  describe "handler/2" do
    test "checks balance of a valid address" do
      {:ok, result} =
        EthBalancePrism.run(%{
          address: @test_address,
          network: "test"
        })

      assert is_float(result.balance_eth)
      assert is_binary(result.balance_wei)
      assert result.network == "test"
    end

    test "defaults to mainnet when network not specified" do
      {:ok, result} =
        EthBalancePrism.run(%{
          address: @test_address,
          network: "test"
        })

      assert result.network == "test"
    end

    test "handles invalid address format" do
      {:error, error} =
        EthBalancePrism.run(%{
          address: "not_an_address",
          network: "test"
        })

      assert String.contains?(error, "Failed to get balance")
    end

    test "handles invalid network" do
      {:error, error} =
        EthBalancePrism.run(%{
          address: @test_address,
          network: "invalid_network"
        })

      assert String.contains?(error, "Invalid network: invalid_network")
    end
  end

  describe "schema validation" do
    test "validates input schema" do
      prism = EthBalancePrism.view()

      assert prism.input_schema.required == ["address"]
      assert Map.has_key?(prism.input_schema.properties, :address)
      assert Map.has_key?(prism.input_schema.properties, :network)

      network_prop = prism.input_schema.properties.network
      assert "test" in network_prop.enum
    end

    test "validates output schema" do
      prism = EthBalancePrism.view()

      assert prism.output_schema.required == ["balance_eth", "balance_wei", "network"]
      assert Map.has_key?(prism.output_schema.properties, :balance_eth)
      assert Map.has_key?(prism.output_schema.properties, :balance_wei)
      assert Map.has_key?(prism.output_schema.properties, :network)
    end
  end
end
