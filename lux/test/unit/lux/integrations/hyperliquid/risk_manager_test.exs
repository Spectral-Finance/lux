defmodule Lux.Integrations.Hyperliquid.RiskManagerTest do
  use UnitAPICase, async: false

  alias Lux.Integrations.Hyperliquid.RiskManager

  setup do
    Req.Test.verify_on_exit!()

    Application.put_env(:lux, :accounts,
      hyperliquid_private_key: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      hyperliquid_address: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      hyperliquid_api_url: "https://api.hyperliquid.xyz"
    )

    Application.put_env(:lux, Lux.Integrations.Hyperliquid.Client,
      plug: {Req.Test, HyperliquidClientMock}
    )

    on_exit(fn ->
      Application.delete_env(:lux, Lux.Integrations.Hyperliquid.Client)
    end)

    {:ok, pid} = GenServer.start_link(RiskManager, [name: :test_risk_manager], [])

    {:ok, pid: pid}
  end

  describe "start_link/1" do
    test "starts the GenServer with default config", %{pid: pid} do
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end

  describe "evaluate_trade/2" do
    test "evaluates a trade with valid parameters", %{pid: pid} do
      trade = %{
        asset: "ETH",
        is_buy: true,
        size: 0.1,
        price: 2800.0,
        leverage: 2
      }

      {:ok, assessment} = RiskManager.evaluate_trade(pid, trade)

      assert is_map(assessment)
      assert Map.has_key?(assessment, :acceptable)
      assert Map.has_key?(assessment, :margin_ratio)
      assert Map.has_key?(assessment, :margin_ratio_status)
      assert Map.has_key?(assessment, :liquidation_risk)
      assert Map.has_key?(assessment, :position_concentration)
      assert Map.has_key?(assessment, :leverage)
      assert Map.has_key?(assessment, :position_size_ratio)
      assert Map.has_key?(assessment, :warnings)
      assert assessment.leverage == 2
    end

    test "warns on excessive leverage", %{pid: pid} do
      trade = %{
        asset: "ETH",
        is_buy: true,
        size: 0.1,
        price: 2800.0,
        leverage: 20
      }

      {:ok, assessment} = RiskManager.evaluate_trade(pid, trade)
      assert assessment.warnings != []
      assert Enum.any?(assessment.warnings, fn w -> String.contains?(w, "Leverage") end)
      assert assessment.acceptable == false
    end
  end

  describe "check_risk/1" do
    test "returns current risk status", %{pid: pid} do
      {:ok, assessment} = RiskManager.check_risk(pid)
      assert is_map(assessment)
      assert Map.has_key?(assessment, :margin_ratio_status)
      assert Map.has_key?(assessment, :warnings)
    end
  end

  describe "update_config/2" do
    test "updates risk configuration", %{pid: pid} do
      RiskManager.update_config(pid, %{max_leverage: 3.0})

      trade = %{
        asset: "ETH",
        is_buy: true,
        size: 0.1,
        price: 2800.0,
        leverage: 5
      }

      {:ok, assessment} = RiskManager.evaluate_trade(pid, trade)
      assert assessment.acceptable == false
    end
  end

  describe "set_stop_loss_take_profit/4" do
    test "attempts to set SL/TP without order manager returns error", %{pid: pid} do
      result = RiskManager.set_stop_loss_take_profit(pid, "ETH", 2500.0, 3200.0)
      assert {:error, :no_order_manager} = result
    end
  end
end
