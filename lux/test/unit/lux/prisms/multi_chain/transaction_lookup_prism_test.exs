defmodule Lux.Prisms.MultiChain.TransactionLookupPrismTest do
  use UnitAPICase, async: false

  alias Lux.MultiChain.Cache
  alias Lux.Prisms.MultiChain.TransactionLookupPrism

  setup do
    Cache.init()
    Cache.clear_all()

    Application.put_env(:lux, :multi_chain, %{
      rpc_endpoints: %{
        ethereum: ["http://localhost:8545"],
        polygon: ["http://localhost:8546"]
      }
    })

    Req.Test.verify_on_exit!()
    :ok
  end

  describe "view/0" do
    test "returns the prism configuration" do
      prism = TransactionLookupPrism.view()
      assert prism.name == "Transaction Lookup"
    end
  end

  describe "handler/2 - single chain" do
    test "looks up a transaction on a specific chain" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "result" => %{
            "hash" => "0xtx_hash",
            "blockNumber" => "0x112A880",
            "from" => "0xSender",
            "to" => "0xReceiver",
            "value" => "0xDE0B6B3A7640000",
            "gas" => "0x5208",
            "gasPrice" => "0x4A817C800",
            "nonce" => "0x2A",
            "input" => "0x"
          }
        })
      end)

      assert {:ok, result} =
               TransactionLookupPrism.handler(
                 %{tx_hash: "0xtx_hash", chain: "ethereum"},
                 nil
               )

      assert result.found_on == "ethereum"
      assert result.transaction.hash == "0xtx_hash"
      assert result.transaction.from == "0xsender"
    end
  end

  describe "handler/2 - multi chain search" do
    test "finds a transaction across chains" do
      # First chain (ethereum) - not found
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "result" => nil
        })
      end)

      # Second chain (polygon) - found
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "result" => %{
            "hash" => "0xtx_hash",
            "blockNumber" => "0x2FAF080",
            "from" => "0xSender",
            "to" => "0xReceiver",
            "value" => "0xDE0B6B3A7640000",
            "gas" => "0x5208",
            "nonce" => "0x1",
            "input" => "0x"
          }
        })
      end)

      assert {:ok, result} =
               TransactionLookupPrism.handler(
                 %{tx_hash: "0xtx_hash", chains: ["ethereum", "polygon"]},
                 nil
               )

      assert result.found_on in ["ethereum", "polygon"]
      assert result.transaction.hash == "0xtx_hash"
    end
  end
end
