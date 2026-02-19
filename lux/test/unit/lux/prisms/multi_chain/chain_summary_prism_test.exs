defmodule Lux.Prisms.MultiChain.ChainSummaryPrismTest do
  use UnitAPICase, async: false

  alias Lux.MultiChain.Cache
  alias Lux.Prisms.MultiChain.ChainSummaryPrism

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
      prism = ChainSummaryPrism.view()
      assert prism.name == "Multi-Chain Summary"
    end
  end

  describe "handler/2" do
    test "returns chain summaries" do
      # Each chain needs block + gas = 2 calls, 2 chains = 4 calls
      for _i <- 1..4 do
        Req.Test.expect(Lux.Lens, fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          decoded = Jason.decode!(body)

          case decoded["method"] do
            "eth_getBlockByNumber" ->
              Req.Test.json(conn, %{
                "jsonrpc" => "2.0",
                "id" => 1,
                "result" => %{
                  "number" => "0x112A880",
                  "hash" => "0xhash",
                  "parentHash" => "0xparent",
                  "timestamp" => "0x64F5A4C0",
                  "miner" => "0xminer",
                  "gasUsed" => "0xE4E1C0",
                  "gasLimit" => "0x1C9C380"
                }
              })

            "eth_gasPrice" ->
              Req.Test.json(conn, %{
                "jsonrpc" => "2.0",
                "id" => 1,
                "result" => "0x4A817C800"
              })

            _ ->
              Req.Test.json(conn, %{
                "jsonrpc" => "2.0",
                "id" => 1,
                "result" => "0x0"
              })
          end
        end)
      end

      assert {:ok, result} =
               ChainSummaryPrism.handler(
                 %{chains: ["ethereum", "polygon"]},
                 nil
               )

      assert result.chains_queried == 2

      for summary <- result.summaries do
        assert summary.chain in ["ethereum", "polygon"]
        assert summary.latest_block > 0
        assert summary.gas_price_gwei > 0
        assert summary.timestamp != nil
      end
    end
  end
end
