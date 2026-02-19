defmodule Lux.Lenses.MultiChain.BalanceLensTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.MultiChain.BalanceLens

  setup do
    Application.put_env(:lux, :api_keys, etherscan: "test_api_key", etherscan_pro: false)
    Req.Test.verify_on_exit!()
  end

  describe "view/0" do
    test "returns a lens with correct configuration" do
      lens = BalanceLens.view()
      assert lens.name == "MultiChain.BalanceLens"
      assert lens.method == :get
      assert lens.url == "https://api.etherscan.io/v2/api"
    end
  end

  describe "focus/2" do
    test "fetches balance for an address" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.params["module"] == "account"
        assert conn.params["action"] == "balance"
        assert conn.params["address"] == "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"

        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => "1000000000000000000"
        })
      end)

      assert {:ok, %{balance_wei: "1000000000000000000", balance_eth: 1.0}} =
               BalanceLens.focus(%{
                 address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
                 chainid: 1
               })
    end

    test "handles error responses" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "NOTOK",
          "result" => "Invalid address"
        })
      end)

      assert {:error, _} =
               BalanceLens.focus(%{
                 address: "invalid",
                 chainid: 1
               })
    end
  end
end
