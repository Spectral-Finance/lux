defmodule Lux.Lenses.MultiChain.BlockLensTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.MultiChain.BlockLens

  setup do
    Application.put_env(:lux, :api_keys, etherscan: "test_api_key", etherscan_pro: false)
    Req.Test.verify_on_exit!()
  end

  describe "view/0" do
    test "returns a lens with correct configuration" do
      lens = BlockLens.view()
      assert lens.name == "MultiChain.BlockLens"
      assert lens.method == :get
    end
  end

  describe "focus/2" do
    test "fetches block reward data" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.params["module"] == "block"
        assert conn.params["action"] == "getblockreward"

        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => %{
            "blockNumber" => "18000000",
            "blockMiner" => "0xminer",
            "blockReward" => "2000000000000000000"
          }
        })
      end)

      assert {:ok, %{result: result}} = BlockLens.focus(%{chainid: 1, blockno: 18_000_000})
      assert result["blockNumber"] == "18000000"
    end

    test "fetches block by timestamp" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.params["module"] == "block"
        assert conn.params["action"] == "getblocknobytime"
        assert conn.params["closest"] == "before"

        Req.Test.json(conn, %{
          "status" => "1",
          "message" => "OK",
          "result" => "18000000"
        })
      end)

      assert {:ok, %{result: "18000000"}} =
               BlockLens.focus(%{chainid: 1, timestamp: 1_693_500_000})
    end
  end
end
