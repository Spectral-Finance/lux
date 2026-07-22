defmodule Lux.Prisms.IndexerPrismTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.IndexerPrism
  alias Lux.Prisms.MultiChainRpcPrism

  setup do
    Req.Test.verify_on_exit!()
    Application.put_env(:lux, :req_options, plug: {Req.Test, MultiChainRpcPrism})
    :ok
  end

  describe "handler/2" do
    test "returns indexed logs" do
      Req.Test.expect(MultiChainRpcPrism, fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        json = Jason.decode!(body)
        assert json["method"] == "eth_getLogs"

        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => json["id"],
          "result" => [%{"logIndex" => "0x1"}, %{"logIndex" => "0x2"}]
        })
      end)

      input = %{chain: "ethereum", contract_address: "0xabc"}
      assert {:ok, %{logs: logs}} = IndexerPrism.handler(input, nil)
      assert length(logs) == 2
    end

    test "returns empty list when logs are nil" do
      Req.Test.expect(MultiChainRpcPrism, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "result" => nil
        })
      end)

      input = %{chain: "ethereum", contract_address: "0xabc"}
      assert {:ok, %{logs: []}} = IndexerPrism.handler(input, nil)
    end

    test "handles string-keyed inputs" do
      Req.Test.expect(MultiChainRpcPrism, fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        json = Jason.decode!(body)
        assert json["method"] == "eth_getLogs"

        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => json["id"],
          "result" => [%{"logIndex" => "0x1"}]
        })
      end)

      input = %{"chain" => "ethereum", "contract_address" => "0xabc"}
      assert {:ok, %{logs: logs}} = IndexerPrism.handler(input, nil)
      assert length(logs) == 1
    end
  end
end
