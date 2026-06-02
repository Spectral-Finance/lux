defmodule Lux.Integrations.Hyperliquid.OrderManagerTest do
  use UnitAPICase, async: false

  import Mock

  alias Lux.Integrations.Hyperliquid.Client
  alias Lux.Integrations.Hyperliquid.OrderManager
  alias Lux.Integrations.Hyperliquid.Models.Order

  setup do
    Application.put_env(:lux, :accounts,
      hyperliquid_private_key: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      hyperliquid_address: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      hyperliquid_api_url: "https://api.hyperliquid.xyz"
    )

    {:ok, pid} =
      GenServer.start_link(OrderManager,
        [name: :test_order_manager, ets_table: :test_hyperliquid_orders],
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

  describe "place_order/2" do
    test "places an order and tracks it in ETS", %{pid: pid} do
      with_mock Client, [:passthrough],
        place_order: fn _params ->
          {:ok, %{"resting" => %{"oid" => 42, "status" => "open"}}}
        end do
        result =
          OrderManager.place_order(pid, %{
            asset: "ETH",
            is_buy: true,
            size: 0.1,
            price: 2800.0,
            order_type: %{limit: %{tif: "Gtc"}},
            reduce_only: false
          })

        assert {:ok, %Order{order_id: 42, asset: "ETH", status: "open"}} = result
      end
    end

    test "handles order placement error", %{pid: pid} do
      with_mock Client, [:passthrough],
        place_order: fn _params -> {:error, "order_error"} end do
        result =
          OrderManager.place_order(pid, %{
            asset: "ETH",
            is_buy: true,
            size: 0.1,
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
end
