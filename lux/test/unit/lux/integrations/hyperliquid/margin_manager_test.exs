defmodule Lux.Integrations.Hyperliquid.MarginManagerTest do
  use UnitAPICase, async: false

  import Mock

  alias Lux.Integrations.Hyperliquid.Client
  alias Lux.Integrations.Hyperliquid.MarginManager

  setup do
    Application.put_env(:lux, :accounts,
      hyperliquid_private_key: "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      hyperliquid_address: "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      hyperliquid_api_url: "https://api.hyperliquid.xyz"
    )

    {:ok, pid} = GenServer.start_link(MarginManager, [name: :test_margin_manager], [])

    {:ok, pid: pid}
  end

  describe "start_link/1" do
    test "starts the GenServer", %{pid: pid} do
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end

  describe "add_margin/3" do
    test "adds margin to a position", %{pid: pid} do
      with_mock Client, [:passthrough],
        modify_margin: fn _asset, _params ->
          {:ok, %{"status" => "ok", "hash" => "0xabc"}}
        end do
        result = MarginManager.add_margin(pid, "ETH", "100")
        assert {:ok, %{asset: "ETH", amount: "100", is_deposit: true, status: "success"}} = result
      end
    end
  end

  describe "remove_margin/3" do
    test "removes margin from a position", %{pid: pid} do
      with_mock Client, [:passthrough],
        modify_margin: fn _asset, _params ->
          {:ok, %{"status" => "ok", "hash" => "0xdef"}}
        end do
        result = MarginManager.remove_margin(pid, "ETH", "50")
        assert {:ok, %{asset: "ETH", amount: "50", is_deposit: false, status: "success"}} = result
      end
    end
  end

  describe "set_leverage/3" do
    test "sets leverage for a position", %{pid: pid} do
      with_mock Client, [:passthrough],
        modify_margin: fn _asset, _params -> {:ok, %{"status" => "ok"}} end do
        assert {:ok, %{"status" => "ok"}} = MarginManager.set_leverage(pid, "ETH", 5)
      end
    end
  end

  describe "set_margin_mode/3" do
    test "switches to cross margin mode", %{pid: pid} do
      with_mock Client, [:passthrough],
        modify_margin: fn _asset, _params -> {:ok, %{"status" => "ok"}} end do
        assert {:ok, _} = MarginManager.set_margin_mode(pid, "ETH", :cross)
      end
    end

    test "switches to isolated margin mode", %{pid: pid} do
      with_mock Client, [:passthrough],
        modify_margin: fn _asset, _params -> {:ok, %{"status" => "ok"}} end do
        assert {:ok, _} = MarginManager.set_margin_mode(pid, "ETH", :isolated)
      end
    end
  end

  describe "get_margin_summary/1" do
    test "returns margin summary", %{pid: pid} do
      assert {:ok, summary} = MarginManager.get_margin_summary(pid)
      assert is_map(summary)
      assert Map.has_key?(summary, :account_value)
      assert Map.has_key?(summary, :total_margin_used)
      assert Map.has_key?(summary, :margin_ratio)
    end
  end

  describe "get_available_margin/1" do
    test "returns available margin", %{pid: pid} do
      assert {:ok, available} = MarginManager.get_available_margin(pid)
      assert is_number(available)
      assert available == 0.0
    end
  end

  describe "get_margin_ratio/1" do
    test "returns margin ratio of 1.0 for zero account value", %{pid: pid} do
      assert {:ok, ratio} = MarginManager.get_margin_ratio(pid)
      assert ratio == 1.0
    end
  end
end
