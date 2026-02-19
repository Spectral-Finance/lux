defmodule Lux.Prisms.GasOptimization.GasPriceEstimatorPrismTest do
  use UnitAPICase, async: false

  alias Lux.Prisms.GasOptimization.GasPriceEstimatorPrism

  setup do
    Application.put_env(:lux, :api_keys, [
      etherscan: "TEST_API_KEY",
      etherscan_pro: false
    ])

    :ok
  end

  defp mock_gas_oracle do
    Req.Test.expect(Lux.Lens, fn conn ->
      Req.Test.json(conn, %{
        "status" => "1",
        "message" => "OK",
        "result" => %{
          "LastBlock" => "19000000",
          "SafeGasPrice" => "15",
          "ProposeGasPrice" => "20",
          "FastGasPrice" => "30",
          "suggestBaseFee" => "18.5",
          "gasUsedRatio" => "0.45,0.52,0.61,0.48,0.55"
        }
      })
    end)
  end

  describe "handler/2" do
    test "estimates gas prices with standard strategy" do
      mock_gas_oracle()

      assert {:ok, result} = GasPriceEstimatorPrism.handler(%{strategy: "standard"}, nil)

      assert result.strategy == "standard"
      assert result.network == "mainnet"
      assert is_number(result.legacy.gas_price_gwei)
      assert result.legacy.gas_price_gwei > 0
      assert is_number(result.eip1559.max_fee_per_gas_gwei)
      assert is_number(result.eip1559.max_priority_fee_per_gas_gwei)
      assert is_number(result.eip1559.base_fee_gwei)
      assert result.eip1559.base_fee_gwei > 0
      assert is_integer(result.estimated_wait_seconds)
      assert is_number(result.confidence)
      assert result.confidence > 0 and result.confidence <= 1
    end

    test "estimates gas prices with slow strategy" do
      mock_gas_oracle()

      assert {:ok, result} = GasPriceEstimatorPrism.handler(%{strategy: "slow"}, nil)

      assert result.strategy == "slow"
      assert result.estimated_wait_seconds == 120
      assert result.legacy.gas_price_gwei <= 20.0
    end

    test "estimates gas prices with fast strategy" do
      mock_gas_oracle()

      assert {:ok, result} = GasPriceEstimatorPrism.handler(%{strategy: "fast"}, nil)

      assert result.strategy == "fast"
      assert result.estimated_wait_seconds == 15
      assert result.legacy.gas_price_gwei >= 20.0
    end

    test "estimates gas prices with instant strategy" do
      mock_gas_oracle()

      assert {:ok, result} = GasPriceEstimatorPrism.handler(%{strategy: "instant"}, nil)

      assert result.strategy == "instant"
      assert result.estimated_wait_seconds == 6
    end

    test "uses default strategy when not specified" do
      mock_gas_oracle()

      assert {:ok, result} = GasPriceEstimatorPrism.handler(%{}, nil)

      assert result.strategy == "standard"
    end

    test "respects max_fee_cap_gwei" do
      mock_gas_oracle()

      assert {:ok, result} =
               GasPriceEstimatorPrism.handler(
                 %{strategy: "instant", max_fee_cap_gwei: 10.0},
                 nil
               )

      assert result.eip1559.max_fee_per_gas_gwei <= 10.0
    end

    test "calculates estimated cost in ETH" do
      mock_gas_oracle()

      assert {:ok, result} =
               GasPriceEstimatorPrism.handler(%{gas_limit: 100_000}, nil)

      assert is_number(result.estimated_cost_eth)
      assert result.estimated_cost_eth > 0
      assert result.gas_limit == 100_000
    end

    test "includes congestion level" do
      mock_gas_oracle()

      assert {:ok, result} = GasPriceEstimatorPrism.handler(%{}, nil)

      assert result.congestion_level in ["low", "moderate", "high", "very_high"]
    end

    test "handles different networks" do
      mock_gas_oracle()

      assert {:ok, result} =
               GasPriceEstimatorPrism.handler(%{network: "sepolia"}, nil)

      assert result.network == "sepolia"
    end
  end

  describe "calculate_estimation/4" do
    test "calculates estimation from oracle data" do
      oracle_data = %{
        suggest_base_fee: 20.0,
        safe_gas_price: 15.0,
        propose_gas_price: 22.0,
        fast_gas_price: 30.0,
        gas_used_ratio: "0.5,0.6,0.7"
      }

      assert {:ok, result} =
               GasPriceEstimatorPrism.calculate_estimation(oracle_data, "standard", 21_000, nil)

      assert is_number(result.legacy.gas_price_gwei)
      assert is_number(result.eip1559.max_fee_per_gas_gwei)
      assert result.eip1559.max_fee_per_gas_gwei > result.eip1559.base_fee_gwei
    end

    test "handles numeric string values in oracle data" do
      oracle_data = %{
        suggest_base_fee: "25.5",
        safe_gas_price: "18",
        propose_gas_price: "25",
        fast_gas_price: "35",
        gas_used_ratio: "0.5"
      }

      assert {:ok, result} =
               GasPriceEstimatorPrism.calculate_estimation(oracle_data, "fast", 21_000, nil)

      assert result.eip1559.base_fee_gwei == 25.5
    end

    test "applies fee cap correctly" do
      oracle_data = %{
        suggest_base_fee: 50.0,
        safe_gas_price: 40.0,
        propose_gas_price: 50.0,
        fast_gas_price: 70.0,
        gas_used_ratio: "0.8"
      }

      assert {:ok, result} =
               GasPriceEstimatorPrism.calculate_estimation(oracle_data, "instant", 21_000, 30.0)

      assert result.eip1559.max_fee_per_gas_gwei <= 30.0
    end
  end

  describe "view/0" do
    test "returns prism struct" do
      prism = GasPriceEstimatorPrism.view()

      assert prism.name == "Gas Price Estimator"
      assert prism.description =~ "gas prices"
      assert prism.input_schema != nil
      assert prism.output_schema != nil
    end
  end
end
