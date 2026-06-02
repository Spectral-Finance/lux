defmodule Lux.Integrations.Binance.PortfolioTest do
  use UnitAPICase, async: false

  import Mock

  alias Lux.Integrations.Binance.Client
  alias Lux.Integrations.Binance.Portfolio
  alias Lux.Integrations.Binance.Models.Position
  alias Lux.Integrations.Binance.Models.Balance

  setup do
    Application.put_env(:lux, :accounts,
      binance_api_key: "test_api_key_abc123",
      binance_secret_key: "test_secret_key_def456",
      hyperliquid_private_key: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      hyperliquid_address: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      hyperliquid_api_url: "https://api.hyperliquid.xyz"
    )

    {:ok, pid} =
      GenServer.start_link(Portfolio,
        [
          name: :test_binance_portfolio,
          positions_ets: :test_binance_positions,
          balances_ets: :test_binance_portfolio_balances
        ],
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
    test "syncs positions from futures API", %{pid: pid} do
      with_mock Client, [:passthrough],
        get_position_info: fn _symbol, _opts ->
          {:ok, [
            %{
              "symbol" => "ETHUSDT",
              "positionAmt" => "1.0",
              "entryPrice" => "2800.0",
              "markPrice" => "2850.0",
              "unRealizedProfit" => "50.0",
              "liquidationPrice" => "1400.0",
              "notional" => "2850.0",
              "initialMargin" => "570.0",
              "maintMargin" => "11.4"
            },
            %{
              "symbol" => "BTCUSDT",
              "positionAmt" => "0.0",
              "entryPrice" => "0.0",
              "markPrice" => "0.0",
              "unRealizedProfit" => "0.0"
            }
          ]}
        end do
        {:ok, positions} = Portfolio.sync_positions(pid)

        assert length(positions) == 1
        assert hd(positions).symbol == "ETHUSDT"
      end
    end

    test "handles sync failure", %{pid: pid} do
      with_mock Client, [:passthrough],
        get_position_info: fn _symbol, _opts -> {:error, :server_error} end do
        assert {:error, :server_error} = Portfolio.sync_positions(pid)
      end
    end
  end

  describe "sync_balances/2" do
    test "syncs spot balances", %{pid: pid} do
      with_mock Client, [:passthrough],
        get_account_info: fn :spot, _opts ->
          {:ok, %{
            "balances" => [
              %{"asset" => "ETH", "free" => "1.5", "locked" => "0.0", "total" => "1.5", "usdValue" => "4200.0"},
              %{"asset" => "USDT", "free" => "5000.0", "locked" => "0.0", "total" => "5000.0", "usdValue" => "5000.0"}
            ]
          }}
        end do
        {:ok, balances} = Portfolio.sync_balances(pid, :spot)

        assert length(balances) == 2
        assert hd(balances).asset == "ETH"
      end
    end
  end

  describe "get_positions/1" do
    test "returns empty list initially", %{pid: pid} do
      assert Portfolio.get_positions(pid) == []
    end
  end

  describe "get_position/2" do
    test "returns nil for non-existent position", %{pid: pid} do
      assert Portfolio.get_position(pid, "NOEXIST") == nil
    end
  end

  describe "calculate_pnl/3" do
    test "calculates PnL for a long position", %{pid: pid} do
      pos = %Position{
        symbol: "ETHUSDT",
        quantity: "1.0",
        entry_price: "2800.0",
        liquidation_price: "1400.0",
        notional: "2800.0",
        unrealized_pnl: "0.0"
      }

      :ets.insert(:test_binance_positions, {"ETHUSDT", pos})

      {:ok, report} = Portfolio.calculate_pnl(pid, "ETHUSDT", 2900.0)

      assert report.symbol == "ETHUSDT"
      assert report.entry_price == 2800.0
      assert report.current_price == 2900.0
      assert report.is_long == true
      assert report.unrealized_pnl == 100.0
    end

    test "calculates PnL for a short position", %{pid: pid} do
      pos = %Position{
        symbol: "ETHUSDT",
        quantity: "-2.0",
        entry_price: "3000.0",
        liquidation_price: "4500.0",
        notional: "6000.0",
        unrealized_pnl: "0.0"
      }

      :ets.insert(:test_binance_positions, {"ETHUSDT", pos})

      {:ok, report} = Portfolio.calculate_pnl(pid, "ETHUSDT", 2800.0)

      assert report.quantity == -2.0
      assert report.is_long == false
      assert report.unrealized_pnl == 400.0
    end

    test "returns error for non-existent position", %{pid: pid} do
      assert {:error, :position_not_found} = Portfolio.calculate_pnl(pid, "NOEXIST", 100.0)
    end
  end

  describe "get_summary/1" do
    test "returns portfolio summary", %{pid: pid} do
      pos1 = %Position{
        symbol: "ETHUSDT",
        quantity: "1.0",
        entry_price: "2800.0",
        liquidation_price: nil,
        unrealized_pnl: "50.0",
        initial_margin: "560.0"
      }

      :ets.insert(:test_binance_positions, {"ETHUSDT", pos1})

      {:ok, summary} = Portfolio.get_summary(pid)

      assert is_map(summary)
      assert Map.has_key?(summary, :total_balance)
      assert Map.has_key?(summary, :total_unrealized_pnl)
      assert Map.has_key?(summary, :total_realized_pnl)
      assert Map.has_key?(summary, :available_balance)
      assert Map.has_key?(summary, :total_margin_used)
      assert Map.has_key?(summary, :margin_ratio)
      assert Map.has_key?(summary, :positions_count)
      assert summary.positions_count == 1
      assert summary.total_unrealized_pnl == 50.0
    end
  end

  describe "get_total_balance/1" do
    test "returns initial balance of 0.0", %{pid: pid} do
      assert Portfolio.get_total_balance(pid) == 0.0
    end
  end

  describe "record_realized_pnl/3" do
    test "records realized PnL for a symbol", %{pid: pid} do
      Portfolio.record_realized_pnl(pid, "ETHUSDT", 100.0)
      {:ok, summary} = Portfolio.get_summary(pid)

      assert summary.total_realized_pnl == 100.0
    end
  end

  describe "get_balances/1" do
    test "returns empty list initially", %{pid: pid} do
      assert Portfolio.get_balances(pid) == []
    end
  end
end
