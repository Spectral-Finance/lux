defmodule Lux.Prisms.PancakeSwap.RiskMonitorPrismTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.PancakeSwap.RiskMonitorPrism

  @ctx %{name: "TestAgent"}

  defp codes(result), do: Enum.map(result.alerts, & &1.code)

  describe "impermanent_loss/1" do
    test "is zero when the price ratio is unchanged" do
      assert RiskMonitorPrism.impermanent_loss(1) == 0.0
    end

    test "matches the constant product formula" do
      # 4x price move -> 20% loss, 2x -> 5.72%
      assert_in_delta RiskMonitorPrism.impermanent_loss(4), -0.2, 1.0e-12
      assert_in_delta RiskMonitorPrism.impermanent_loss(2), -0.0572, 1.0e-4
    end

    test "is symmetric for inverse price moves" do
      assert_in_delta RiskMonitorPrism.impermanent_loss(4),
                      RiskMonitorPrism.impermanent_loss(0.25),
                      1.0e-12
    end
  end

  describe "handler/2" do
    test "reports low risk when nothing is wrong" do
      assert {:ok, %{risk_level: "low", alerts: []} = result} =
               RiskMonitorPrism.handler(
                 %{
                   entry_price_ratio: 100,
                   current_price_ratio: 101,
                   pool_tvl_usd: 50_000_000,
                   position_usd: 10_000,
                   cake_per_block: "1000"
                 },
                 @ctx
               )

      assert_in_delta result.impermanent_loss, 0.0, 1.0e-4
      assert_in_delta result.pool_share, 0.0002, 1.0e-9
    end

    test "returns low risk without any inputs" do
      assert {:ok, %{risk_level: "low", alerts: []}} = RiskMonitorPrism.handler(%{}, @ctx)
    end

    test "flags impermanent loss above the threshold" do
      # 2x move = 5.72% loss > 5%: medium
      assert {:ok, %{risk_level: "medium"} = medium} =
               RiskMonitorPrism.handler(%{entry_price_ratio: 100, current_price_ratio: 200}, @ctx)

      assert codes(medium) == ["impermanent_loss"]
      assert [%{severity: "medium", message: message}] = medium.alerts
      assert message =~ "5.72%"

      # 4x move = 20% loss > 10%: high
      assert {:ok, %{risk_level: "high"} = high} =
               RiskMonitorPrism.handler(%{entry_price_ratio: 100, current_price_ratio: 400}, @ctx)

      assert_in_delta high.impermanent_loss, -0.2, 1.0e-12
    end

    test "honours max_impermanent_loss" do
      assert {:ok, %{risk_level: "low"}} =
               RiskMonitorPrism.handler(
                 %{entry_price_ratio: 100, current_price_ratio: 200, max_impermanent_loss: 0.1},
                 @ctx
               )
    end

    test "flags low TVL" do
      assert {:ok, %{risk_level: "medium"} = medium} =
               RiskMonitorPrism.handler(%{pool_tvl_usd: 500_000}, @ctx)

      assert codes(medium) == ["low_tvl"]

      assert {:ok, %{risk_level: "high"} = high} =
               RiskMonitorPrism.handler(%{pool_tvl_usd: 50_000}, @ctx)

      assert [%{code: "low_tvl", severity: "high"}] = high.alerts

      assert {:ok, %{risk_level: "low"}} =
               RiskMonitorPrism.handler(%{pool_tvl_usd: 500_000, min_tvl_usd: 100_000}, @ctx)
    end

    test "flags a position that is a large share of the pool" do
      assert {:ok, %{risk_level: "medium"} = result} =
               RiskMonitorPrism.handler(
                 %{pool_tvl_usd: 10_000_000, position_usd: 2_000_000},
                 @ctx
               )

      assert codes(result) == ["pool_concentration"]
      assert_in_delta result.pool_share, 0.2, 1.0e-12
    end

    test "flags stopped emissions as high risk" do
      assert {:ok, %{risk_level: "high", alerts: [%{code: "emissions_stopped"}]}} =
               RiskMonitorPrism.handler(%{cake_per_block: 0}, @ctx)

      assert {:ok, %{alerts: [%{code: "emissions_stopped"}]}} =
               RiskMonitorPrism.handler(%{cake_per_block: "0"}, @ctx)
    end

    test "combines alerts and takes the highest severity" do
      assert {:ok, result} =
               RiskMonitorPrism.handler(
                 %{
                   entry_price_ratio: 1,
                   current_price_ratio: 2,
                   pool_tvl_usd: 500_000,
                   position_usd: 100_000
                 },
                 @ctx
               )

      assert result.risk_level == "medium"
      assert Enum.sort(codes(result)) == ["impermanent_loss", "low_tvl", "pool_concentration"]
    end

    test "validates the input" do
      assert {:error, "entry_price_ratio and current_price_ratio must be provided together"} =
               RiskMonitorPrism.handler(%{entry_price_ratio: 1}, @ctx)

      assert {:error, message} =
               RiskMonitorPrism.handler(%{entry_price_ratio: 0, current_price_ratio: 1}, @ctx)

      assert message =~ "entry_price_ratio must be a positive number"

      assert {:error, message} = RiskMonitorPrism.handler(%{pool_tvl_usd: -5}, @ctx)
      assert message =~ "pool_tvl_usd must be a positive number"

      assert {:error, message} = RiskMonitorPrism.handler(%{min_tvl_usd: -1}, @ctx)
      assert message =~ "non-negative"

      assert {:error, "cake_per_block must be a non-negative integer (wei)"} =
               RiskMonitorPrism.handler(%{cake_per_block: "abc"}, @ctx)
    end
  end
end
