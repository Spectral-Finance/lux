defmodule Lux.Integrations.Hyperliquid.PositionManagerTest do
  use UnitAPICase, async: false

  import Mock

  alias Lux.Integrations.Hyperliquid.Client
  alias Lux.Integrations.Hyperliquid.PositionManager
  alias Lux.Integrations.Hyperliquid.Models.Position

  setup do
    Application.put_env(:lux, :accounts,
      hyperliquid_private_key: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      hyperliquid_address: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      hyperliquid_api_url: "https://api.hyperliquid.xyz"
    )

    {:ok, pid} =
      GenServer.start_link(PositionManager,
        [name: :test_position_manager, ets_table: :test_hyperliquid_positions],
        []
      )

    {:ok, pid: pid}
  end

  describe "start_link/1" do
    test "starts the GenServer successfully", %{pid: pid} do
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end

  describe "sync_positions/1" do
    test "syncs positions from API and stores in ETS", %{pid: pid} do
      with_mock Client, [:passthrough],
        get_account_info: fn _address ->
          {:ok, %{
            "crossMarginSummary" => %{
              "accountValue" => "10000.0",
              "totalMarginUsed" => "2000.0",
              "totalNtlPos" => "4000.0",
              "totalRawUsd" => "10000.0"
            },
            "crossMaintenanceMarginRatio" => "0.0625",
            "assetPositions" => [
              %{
                "coin" => "ETH",
                "position" => %{
                  "szi" => "1.0",
                  "entryPx" => "2800.0",
                  "leverage" => %{"value" => "2"},
                  "liquidationPx" => "1400.0",
                  "marginUsed" => "1400.0",
                  "positionValue" => "2800.0",
                  "returnOnEquity" => "0.15",
                  "unrealizedPnl" => "420.0",
                  "marginMode" => "cross",
                  "maxLeverage" => "10"
                }
              }
            ]
          }}
        end do
        assert {:ok, [%Position{asset: "ETH"} = _pos]} = PositionManager.sync_positions(pid)
      end
    end

    test "handles sync failure", %{pid: pid} do
      with_mock Client, [:passthrough],
        get_account_info: fn _address -> {:error, :server_error} end do
        assert {:error, :server_error} = PositionManager.sync_positions(pid)
      end
    end
  end

  describe "get_positions/1" do
    test "returns empty list initially", %{pid: pid} do
      assert PositionManager.get_positions(pid) == []
    end
  end

  describe "get_position/2" do
    test "returns nil for non-existent position", %{pid: pid} do
      assert PositionManager.get_position(pid, "NOEXIST") == nil
    end
  end

  describe "calculate_pnl/3" do
    test "calculates PnL for a long position", %{pid: pid} do
      pos = %Position{
        asset: "ETH",
        size: "1.0",
        entry_price: "2800.0",
        liquidation_price: "1400.0",
        position_value: "2800.0"
      }

      :ets.insert(:test_hyperliquid_positions, {"ETH", pos})

      {:ok, report} = PositionManager.calculate_pnl(pid, "ETH", 2900.0)

      assert report.asset == "ETH"
      assert report.entry_price == 2800.0
      assert report.current_price == 2900.0
      assert report.is_long == true
      assert report.unrealized_pnl == 100.0
    end

    test "calculates PnL for a short position", %{pid: pid} do
      pos = %Position{
        asset: "ETH",
        size: "-2.0",
        entry_price: "3000.0",
        liquidation_price: "4500.0",
        position_value: "6000.0"
      }

      :ets.insert(:test_hyperliquid_positions, {"ETH", pos})

      {:ok, report} = PositionManager.calculate_pnl(pid, "ETH", 2800.0)

      assert report.size == -2.0
      assert report.is_long == false
      assert report.unrealized_pnl == 400.0
    end

    test "returns error for non-existent position", %{pid: pid} do
      assert {:error, :position_not_found} = PositionManager.calculate_pnl(pid, "NOEXIST", 100.0)
    end
  end

  describe "calculate_portfolio_pnl/2" do
    test "calculates total PnL across all positions", %{pid: pid} do
      pos1 = %Position{
        asset: "ETH",
        size: "1.0",
        entry_price: "2800.0",
        liquidation_price: nil,
        position_value: "2800.0"
      }

      pos2 = %Position{
        asset: "BTC",
        size: "-0.5",
        entry_price: "62000.0",
        liquidation_price: nil,
        position_value: "31000.0"
      }

      :ets.insert(:test_hyperliquid_positions, {"ETH", pos1})
      :ets.insert(:test_hyperliquid_positions, {"BTC", pos2})

      prices = %{"ETH" => 2900.0, "BTC" => 60000.0}

      {:ok, report} = PositionManager.calculate_portfolio_pnl(pid, prices)

      assert length(report.positions) == 2
      assert report.total_unrealized_pnl > 0
    end
  end

  describe "get_account_value/1" do
    test "returns initial account value", %{pid: pid} do
      assert PositionManager.get_account_value(pid) == 0.0
    end
  end
end
