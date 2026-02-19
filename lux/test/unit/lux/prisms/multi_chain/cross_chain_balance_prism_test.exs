defmodule Lux.Prisms.MultiChain.CrossChainBalancePrismTest do
  use UnitAPICase, async: false

  alias Lux.MultiChain.Cache
  alias Lux.Prisms.MultiChain.CrossChainBalancePrism

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
      prism = CrossChainBalancePrism.view()
      assert prism.name == "Cross-Chain Balance Aggregator"
      assert prism.input_schema != nil
      assert prism.output_schema != nil
    end
  end

  describe "handler/2" do
    test "aggregates balances across chains" do
      for _i <- 1..2 do
        Req.Test.expect(Lux.Lens, fn conn ->
          Req.Test.json(conn, %{
            "jsonrpc" => "2.0",
            "id" => 1,
            "result" => "0xDE0B6B3A7640000"
          })
        end)
      end

      assert {:ok, result} =
               CrossChainBalancePrism.handler(
                 %{
                   address: "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
                   chains: ["ethereum", "polygon"]
                 },
                 nil
               )

      assert result.address == "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
      assert result.total_chains_queried == 2
      assert result.successful_chains == 2
      assert length(result.balances) == 2

      for balance <- result.balances do
        assert balance.balance == 1.0
        assert balance.chain in ["ethereum", "polygon"]
      end
    end

    test "handles string-keyed input" do
      for _i <- 1..2 do
        Req.Test.expect(Lux.Lens, fn conn ->
          Req.Test.json(conn, %{
            "jsonrpc" => "2.0",
            "id" => 1,
            "result" => "0xDE0B6B3A7640000"
          })
        end)
      end

      assert {:ok, result} =
               CrossChainBalancePrism.handler(
                 %{
                   "address" => "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
                   "chains" => ["ethereum", "polygon"]
                 },
                 nil
               )

      assert result.address == "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
    end
  end
end
