defmodule Lux.Lenses.MultiChain.EventLogLensTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.MultiChain.EventLogLens

  setup do
    Application.put_env(:lux, :api_keys, etherscan: "test_api_key", etherscan_pro: false)
    Req.Test.verify_on_exit!()
  end

  describe "view/0" do
    test "returns a lens with correct configuration" do
      lens = EventLogLens.view()
      assert lens.name == "MultiChain.EventLogLens"
      assert lens.method == :get
    end
  end

  describe "focus/2" do
    test "fetches event logs for a contract" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.params["module"] == "logs"
        assert conn.params["action"] == "getLogs"

        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => [
            %{
              "address" => "0xdAC17F958D2ee523a2206206994597C13D831ec7",
              "topics" => [
                "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
              ],
              "data" => "0x000000000000000000000000000000000000000000000000000000003b9aca00",
              "blockNumber" => "0x112A880",
              "transactionHash" => "0xtx_hash",
              "logIndex" => "0x5"
            }
          ]
        })
      end)

      assert {:ok, %{result: [event | _]}} =
               EventLogLens.focus(%{
                 address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
                 chainid: 1,
                 topic0:
                   "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
                 fromBlock: 18_000_000,
                 toBlock: 18_000_100
               })

      assert event["transactionHash"] == "0xtx_hash"
    end
  end
end
