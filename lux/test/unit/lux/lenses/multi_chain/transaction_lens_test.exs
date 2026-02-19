defmodule Lux.Lenses.MultiChain.TransactionLensTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.MultiChain.TransactionLens

  setup do
    Application.put_env(:lux, :api_keys, etherscan: "test_api_key", etherscan_pro: false)
    Req.Test.verify_on_exit!()
  end

  describe "view/0" do
    test "returns a lens with correct configuration" do
      lens = TransactionLens.view()
      assert lens.name == "MultiChain.TransactionLens"
      assert lens.method == :get
    end
  end

  describe "focus/2" do
    test "fetches transaction list for an address" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.params["module"] == "account"
        assert conn.params["action"] == "txlist"
        assert conn.params["address"] == "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"

        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "hash" => "0xtx1",
              "blockNumber" => "18000000",
              "from" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
              "to" => "0xReceiver",
              "value" => "1000000000000000000",
              "gasUsed" => "21000"
            }
          ]
        })
      end)

      assert {:ok, %{result: [tx | _]}} =
               TransactionLens.focus(%{
                 address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
                 chainid: 1
               })

      assert tx["hash"] == "0xtx1"
    end

    test "handles no transactions found" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "status" => "0",
          "message" => "No transactions found",
          "result" => "No transactions found"
        })
      end)

      assert {:error, _} =
               TransactionLens.focus(%{
                 address: "0x0000000000000000000000000000000000000000",
                 chainid: 1
               })
    end
  end
end
