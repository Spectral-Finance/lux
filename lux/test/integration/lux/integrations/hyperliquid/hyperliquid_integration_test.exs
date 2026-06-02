defmodule Lux.Integrations.Hyperliquid.IntegrationTest do
  use ExUnit.Case, async: false

  import Mock

  alias Lux.Integrations.Hyperliquid.AssetResolver
  alias Lux.Integrations.Hyperliquid.Client
  alias Lux.Integrations.Hyperliquid.MarginManager
  alias Lux.Integrations.Hyperliquid.OrderManager
  alias Lux.Integrations.Hyperliquid.PositionManager
  alias Lux.Integrations.Hyperliquid.RiskManager

  setup do
    Application.put_env(:lux, :accounts,
      hyperliquid_private_key: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      hyperliquid_address: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      hyperliquid_api_url: "https://api.hyperliquid.xyz"
    )

    on_exit(fn ->
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, true)
    end)

    :ok
  end

  describe "sandbox guard" do
    test "private actions are blocked by default without explicit opt-in" do
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, false)

      assert {:error, :live_trading_disabled} =
               Client.place_order(%{asset: "ETH", is_buy: true, size: 0.1, price: 2800.0})

      assert {:error, :live_trading_disabled} =
               Client.cancel_order("ETH", 123_456)

      assert {:error, :live_trading_disabled} =
               Client.cancel_orders([%{asset: "ETH", order_id: 1}])

      assert {:error, :live_trading_disabled} =
               Client.modify_margin("ETH", %{is_deposit: true, amount: "100"})

      assert {:error, :live_trading_disabled} =
               Client.query_private(%{type: "order", orders: [], grouping: "na"})
    end

    test "private actions work when live trading is explicitly enabled" do
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, true)
      Req.Test.verify_on_exit!()

      Req.Test.expect(HyperliquidIntegrationMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"status" => "ok"}))
      end)

      result = Client.query_private(
        %{type: "order", orders: [], grouping: "na"},
        plug: {Req.Test, HyperliquidIntegrationMock}
      )
      refute result == {:error, :live_trading_disabled}
    end

    test "public queries are never blocked by sandbox guard" do
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, false)
      Req.Test.verify_on_exit!()

      Req.Test.expect(HyperliquidIntegrationMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"ETH" => "2800.0"}))
      end)

      assert {:ok, _} = Client.query_public(%{type: "allMids"},
        plug: {Req.Test, HyperliquidIntegrationMock})
    end
  end

  describe "margin/leverage payloads" do
    test "add isolated margin sends correct action" do
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, true)
      Req.Test.verify_on_exit!()

      Req.Test.expect(HyperliquidIntegrationMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["action"]["type"] == "updateIsolatedMargin"
        assert decoded["action"]["isBuy"] == true
        assert decoded["action"]["asset"] == "ETH"
        assert decoded["action"]["ntli"] == "100"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"status" => "ok"}))
      end)

      assert {:ok, _} = Client.modify_margin("ETH", %{is_deposit: true, amount: "100"},
        plug: {Req.Test, HyperliquidIntegrationMock})
    end

    test "remove isolated margin sends correct action" do
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, true)
      Req.Test.verify_on_exit!()

      Req.Test.expect(HyperliquidIntegrationMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["action"]["type"] == "updateIsolatedMargin"
        assert decoded["action"]["isBuy"] == false
        assert decoded["action"]["asset"] == "ETH"
        assert decoded["action"]["ntli"] == "50"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"status" => "ok"}))
      end)

      assert {:ok, _} = Client.modify_margin("ETH", %{is_deposit: false, amount: "50"},
        plug: {Req.Test, HyperliquidIntegrationMock})
    end

    test "set cross margin mode sends correct action" do
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, true)
      Req.Test.verify_on_exit!()

      Req.Test.expect(HyperliquidIntegrationMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["action"]["type"] == "updateLeverage"
        assert decoded["action"]["isCross"] == true
        assert decoded["action"]["asset"] == "ETH"
        assert decoded["action"]["leverage"] >= 1

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"status" => "ok"}))
      end)

      assert {:ok, _} = Client.modify_margin("ETH", %{is_cross: true, leverage: 3},
        plug: {Req.Test, HyperliquidIntegrationMock})
    end

    test "update leverage sends correct action" do
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, true)
      Req.Test.verify_on_exit!()

      Req.Test.expect(HyperliquidIntegrationMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["action"]["type"] == "updateLeverage"
        assert decoded["action"]["asset"] == "ETH"
        assert decoded["action"]["leverage"] == 10
        assert decoded["action"]["isCross"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"status" => "ok"}))
      end)

      assert {:ok, _} = Client.modify_margin("ETH", %{leverage: 10, is_cross: true},
        plug: {Req.Test, HyperliquidIntegrationMock})
    end

    test "deposit and withdraw cannot be confused" do
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, true)
      Req.Test.verify_on_exit!()

      # Deposit
      Req.Test.expect(HyperliquidIntegrationMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["action"]["type"] == "updateIsolatedMargin"
        assert decoded["action"]["isBuy"] == true
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"status" => "ok"}))
      end)

      {:ok, _} = Client.modify_margin("ETH", %{is_deposit: true, amount: "200"},
        plug: {Req.Test, HyperliquidIntegrationMock})

      # Withdraw
      Req.Test.expect(HyperliquidIntegrationMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["action"]["type"] == "updateIsolatedMargin"
        assert decoded["action"]["isBuy"] == false
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"status" => "ok"}))
      end)

      {:ok, _} = Client.modify_margin("ETH", %{is_deposit: false, amount: "200"},
        plug: {Req.Test, HyperliquidIntegrationMock})
    end
  end

  describe "risk management" do
    test "evaluates trade risk with complete assessment" do
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, true)

      {:ok, _pid} = RiskManager.start_link(name: :integration_risk)
      trade = %{asset: "ETH", is_buy: true, size: 1.0, price: 2800.0, leverage: 2}

      {:ok, assessment} = RiskManager.evaluate_trade(:integration_risk, trade)

      assert is_map(assessment)
      assert Map.has_key?(assessment, :acceptable)
      assert Map.has_key?(assessment, :margin_ratio)
      assert Map.has_key?(assessment, :margin_ratio_status)
      assert Map.has_key?(assessment, :liquidation_risk)
      assert Map.has_key?(assessment, :position_concentration)
      assert Map.has_key?(assessment, :leverage)
      assert Map.has_key?(assessment, :position_size_ratio)
      assert Map.has_key?(assessment, :warnings)
    end

    test "rejects trade with excessive leverage" do
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, true)

      {:ok, _pid} = RiskManager.start_link(name: :integration_risk2)
      trade = %{asset: "ETH", is_buy: true, size: 0.1, price: 2800.0, leverage: 25}

      {:ok, assessment} = RiskManager.evaluate_trade(:integration_risk2, trade)

      assert assessment.acceptable == false
      assert Enum.any?(assessment.warnings, &String.contains?(&1, "Leverage"))
    end

    test "check_risk returns structured assessment" do
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, true)

      {:ok, _pid} = RiskManager.start_link(name: :integration_risk3)
      {:ok, assessment} = RiskManager.check_risk(:integration_risk3)

      assert is_map(assessment)
      assert assessment.margin_ratio_status in [:safe, :warning, :critical]
      assert is_list(assessment.warnings)
    end

    test "risk config can be updated at runtime" do
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, true)

      {:ok, _pid} = RiskManager.start_link(name: :integration_risk4)
      RiskManager.update_config(:integration_risk4, %{max_leverage: 2.0})

      trade = %{asset: "ETH", is_buy: true, size: 0.1, price: 2800.0, leverage: 3}
      {:ok, assessment} = RiskManager.evaluate_trade(:integration_risk4, trade)

      assert assessment.acceptable == false
    end
  end

  describe "order lifecycle" do
    test "place_order tracks order in ETS" do
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, true)

      {:ok, _pid} = OrderManager.start_link(
        name: :integration_order, ets_table: :integration_orders)

      with_mock Client, [:passthrough],
        place_order: fn _params ->
          {:ok, %{"resting" => %{"oid" => 42, "status" => "open"}}}
        end do
        {:ok, order} = OrderManager.place_order(:integration_order, %{
          asset: "ETH",
          is_buy: true,
          size: 0.5,
          price: 2800.0,
          order_type: %{limit: %{tif: "Gtc"}}
        })

        assert order.order_id == 42
        assert order.status == "open"
        assert order.asset == "ETH"

        {:ok, retrieved} = OrderManager.get_order_state(:integration_order, 42)
        assert retrieved.order_id == 42
      end
    end

    test "cancel_all_orders cancels active orders" do
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, true)

      {:ok, _pid} = OrderManager.start_link(
        name: :integration_order2, ets_table: :integration_orders2)

      with_mock Client, [:passthrough],
        place_order: fn _params ->
          {:ok, %{"resting" => %{"oid" => 1, "status" => "open"}}}
        end,
        cancel_orders: fn _cancels -> {:ok, %{"status" => "ok"}} end do
        {:ok, _} = OrderManager.place_order(:integration_order2, %{
          asset: "ETH", is_buy: true, size: 0.1, price: 2800.0
        })

        {:ok, count} = OrderManager.cancel_all_orders(:integration_order2)
        assert count == 1
      end
    end
  end

  describe "position tracking" do
    test "sync_positions fetches and caches positions" do
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, true)

      {:ok, _pid} = PositionManager.start_link(
        name: :integration_pos, ets_table: :integration_positions)

      with_mock Client, [:passthrough],
        get_account_info: fn _address ->
          {:ok, %{
            "crossMarginSummary" => %{
              "accountValue" => "50000.0",
              "totalMarginUsed" => "10000.0",
              "totalNtlPos" => "30000.0",
              "totalRawUsd" => "50000.0"
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
        {:ok, positions} = PositionManager.sync_positions(:integration_pos)
        assert length(positions) == 1
        assert hd(positions).asset == "ETH"
      end
    end

    test "get_positions returns empty list initially" do
      Application.put_env(:lux, :hyperliquid_live_trading_allowed, true)

      {:ok, _pid} = PositionManager.start_link(
        name: :integration_pos2, ets_table: :integration_positions2)

      assert PositionManager.get_positions(:integration_pos2) == []
    end
  end

  describe "asset resolver" do
    test "resolves known asset from fixtures without API call" do
      {:ok, _pid} = AssetResolver.start_link(name: :test_asset_resolver)

      eth = AssetResolver.resolve("ETH")
      assert eth.asset_name == "ETH"
      assert eth.asset_id == 1
      assert eth.sz_decimals == 5

      btc = AssetResolver.resolve("BTC")
      assert btc.asset_name == "BTC"
      assert btc.asset_id == 0

      unknown = AssetResolver.resolve("NONEXIST")
      assert unknown.asset_name == "NONEXIST"
      assert unknown.sz_decimals == 5
    end

    test "sz_decimals returns correct precision" do
      assert AssetResolver.sz_decimals("ETH") == 5
      assert AssetResolver.sz_decimals("PEPE") == 0
      assert AssetResolver.sz_decimals("UNKNOWN") == 5
    end

    test "tick_size returns correct value" do
      assert AssetResolver.tick_size("ETH") == 0.00001
      assert AssetResolver.tick_size("PEPE") == 1.0
    end
  end
end
