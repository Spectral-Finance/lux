defmodule Lux.Integrations.Binance.OrderManagerTest do
  use UnitAPICase, async: false

  import Mock

  alias Lux.Integrations.Binance.Client
  alias Lux.Integrations.Binance.OrderManager
  alias Lux.Integrations.Binance.Models.Order

  setup do
    Application.put_env(:lux, :accounts,
      binance_api_key: "test_api_key_abc123",
      binance_secret_key: "test_secret_key_def456"
    )

    {:ok, pid} =
      GenServer.start_link(OrderManager,
        [name: :test_binance_order_manager, ets_table: :test_binance_orders],
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

  describe "place_order/3" do
    test "places a spot limit order and tracks it in ETS", %{pid: pid} do
      with_mock Client, [:passthrough],
        place_order: fn :spot, _params, _opts ->
          {:ok, %{
            "orderId" => 42,
            "symbol" => "ETHUSDT",
            "side" => "BUY",
            "type" => "LIMIT",
            "price" => "2800.0",
            "origQty" => "0.1",
            "status" => "NEW"
          }}
        end do
        result =
          OrderManager.place_order(pid, :spot, %{
            symbol: "ETHUSDT",
            side: "BUY",
            type: "LIMIT",
            quantity: 0.1,
            price: 2800.0,
            time_in_force: "GTC"
          })

        assert {:ok, %Order{order_id: 42, symbol: "ETHUSDT", status: "NEW"}} = result
      end
    end

    test "handles order placement error", %{pid: pid} do
      with_mock Client, [:passthrough],
        place_order: fn :spot, _params, _opts -> {:error, "order_error"} end do
        result =
          OrderManager.place_order(pid, :spot, %{
            symbol: "ETHUSDT",
            side: "BUY",
            type: "LIMIT",
            quantity: 0.1,
            price: 2800.0
          })

        assert {:error, "order_error"} = result
      end
    end
  end

  describe "get_open_orders/1" do
    test "returns empty list when no orders", %{pid: pid} do
      assert OrderManager.get_open_orders(pid) == []
    end
  end

  describe "get_order_state/2" do
    test "returns error for non-existent order", %{pid: pid} do
      assert {:error, :not_found} = OrderManager.get_order_state(pid, 99_999)
    end
  end

  describe "handle_execution_report/2" do
    test "processes execution report event", %{pid: pid} do
      event = %{
        "i" => 42,
        "symbol" => "ETHUSDT",
        "side" => "BUY",
        "type" => "LIMIT",
        "origQty" => "0.1",
        "price" => "2800.0",
        "status" => "FILLED",
        "executedQty" => "0.1",
        "cummulativeQuoteQty" => "280.0"
      }

      OrderManager.handle_execution_report(pid, event)

      {:ok, order} = OrderManager.get_order_state(pid, 42)
      assert order.status == "FILLED"
    end
  end
end
