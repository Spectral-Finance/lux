defmodule Lux.Integration.GasOptimizationTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.GasOptimizerPrism
  alias Lux.Prisms.TxManagerPrism

  @moduletag :integration

  describe "GasOptimizerPrism" do
    test "predict_gas action works on testnet" do
      result = GasOptimizerPrism.run(%{
        action: "predict",
        network: "test"
      })

      assert {:ok, %{result: result_data}} = result
      assert Map.has_key?(result_data, :gas_price_wei)
      assert Map.has_key?(result_data, :gas_price_gwei)
      assert Map.has_key?(result_data, :estimated_base_fee_gwei)
    end

    test "priority_fee action works on testnet" do
      result = GasOptimizerPrism.run(%{
        action: "priority_fee",
        network: "test"
      })

      assert {:ok, %{result: result_data}} = result
      assert Map.has_key?(result_data, :optimized_priority_fee_wei)
      assert Map.has_key?(result_data, :optimized_priority_fee_gwei)
    end

    test "cost_analysis action works on testnet" do
      result = GasOptimizerPrism.run(%{
        action: "cost_analysis",
        network: "test",
        gas_limit: 50000
      })

      assert {:ok, %{result: result_data}} = result
      assert Map.has_key?(result_data, :estimated_cost_wei)
      assert Map.has_key?(result_data, :estimated_cost_eth)
      assert result_data.gas_limit_used == 50000
    end
  end

  describe "TxManagerPrism" do
    test "batch transactions" do
      result = TxManagerPrism.run(%{
        action: "batch",
        network: "test",
        payload: %{
          "transactions" => [
            %{"to" => "0x0000000000000000000000000000000000000000", "value" => 100},
            %{"to" => "0x0000000000000000000000000000000000000000", "value" => 200}
          ]
        }
      })

      assert {:ok, %{result: result_data}} = result
      assert result_data.batch_size == 2
      assert result_data.status == "batched_for_execution"
    end

    test "replace transaction (speed up)" do
      result = TxManagerPrism.run(%{
        action: "replace",
        network: "test",
        payload: %{
          "tx_hash" => "0xabcdef123456",
          "type" => "speed_up"
        }
      })

      assert {:ok, %{result: result_data}} = result
      assert result_data.original_tx == "0xabcdef123456"
      assert result_data.replacement_type == "speed_up"
      assert Map.has_key?(result_data, :new_gas_price_wei)
    end

    test "mev protection" do
      result = TxManagerPrism.run(%{
        action: "mev_protect",
        network: "test",
        payload: %{
          "transaction" => %{"to" => "0x0000000000000000000000000000000000000000", "value" => 100}
        }
      })

      assert {:ok, %{result: result_data}} = result
      assert result_data.status == "mev_protected"
      assert result_data.rpc_used == "https://rpc.flashbots.net"
    end

    test "gas token integration" do
      result = TxManagerPrism.run(%{
        action: "gas_token",
        network: "test",
        payload: %{
          "transaction" => %{"to" => "0x0000000000000000000000000000000000000000", "value" => 100},
          "token_address" => "0xTokenAddress"
        }
      })

      assert {:ok, %{result: result_data}} = result
      assert result_data.status == "gas_token_enabled"
      assert result_data.token_address == "0xTokenAddress"
    end
  end
end
