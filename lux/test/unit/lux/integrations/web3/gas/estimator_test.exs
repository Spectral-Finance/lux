defmodule Lux.Integrations.Web3.Gas.EstimatorTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Web3.Gas.Estimator

  setup do
    Req.Test.stub(Lux.Web3.GasMock, fn conn ->
      {:ok, body, _} = Plug.Conn.read_body(conn)
      req = Jason.decode!(body)

      result = case req["method"] do
        "eth_gasPrice" -> "0x6FC23AC00"  # ~30 gwei
        "eth_maxPriorityFeePerGas" -> "0x3B9ACA00"  # 1 gwei
        "eth_getBlockByNumber" -> %{"baseFeePerGas" => "0x6FC23AC00", "number" => "0xF4240"}
        "eth_estimateGas" -> "0x5208"  # 21000
      end

      Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => result})
    end)
    :ok
  end

  test "estimate returns 3 tiers" do
    assert {:ok, result} = Estimator.estimate(rpc_url: "https://test", plug: {Req.Test, Lux.Web3.GasMock})

    assert result.slow.max_fee_per_gas > 0
    assert result.standard.max_fee_per_gas > result.slow.max_fee_per_gas
    assert result.fast.max_fee_per_gas > result.standard.max_fee_per_gas
    assert result.base_fee_gwei > 0
  end

  test "estimate_gas returns gas estimate" do
    assert {:ok, result} = Estimator.estimate_gas(
      %{to: "0xabc", value: 1_000_000_000_000_000_000},
      rpc_url: "https://test", plug: {Req.Test, Lux.Web3.GasMock}
    )

    assert result.gas_estimate == 21_000
    assert result.gas_with_buffer == 25_200
  end

  test "calculate_cost without USD" do
    result = Estimator.calculate_cost(21_000, 30.0)
    assert result.gas_limit == 21_000
    assert result.cost_eth > 0
    refute Map.has_key?(result, :cost_usd)
  end

  test "calculate_cost with USD" do
    result = Estimator.calculate_cost(21_000, 30.0, 2500.0)
    assert result.cost_usd > 0
  end
end
