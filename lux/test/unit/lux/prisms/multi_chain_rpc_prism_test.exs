defmodule Lux.Prisms.MultiChainRpcPrismTest do
  use UnitAPICase, async: false

  alias Lux.Prisms.MultiChainRpcPrism

  setup do
    Req.Test.verify_on_exit!()

    existing_req_options = Application.get_env(:lux, :req_options)

    # Override configuration to use the mock plug for the test
    Application.put_env(:lux, :req_options, plug: {Req.Test, MultiChainRpcPrism})

    on_exit(fn ->
      if existing_req_options do
        Application.put_env(:lux, :req_options, existing_req_options)
      else
        Application.delete_env(:lux, :req_options)
      end
    end)

    :ok
  end

  describe "handler/2" do
    test "returns the RPC result successfully" do
      Req.Test.expect(MultiChainRpcPrism, fn conn ->
        assert conn.method == "POST"
        {:ok, body, _} = Plug.Conn.read_body(conn)
        json = Jason.decode!(body)
        assert json["method"] == "eth_blockNumber"

        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => json["id"], "result" => "0x1b4"})
      end)

      input = %{chain: "ethereum", method: "eth_blockNumber", params: []}
      assert {:ok, %{result: "0x1b4", chain: "ethereum"}} = MultiChainRpcPrism.handler(input, nil)
    end

    test "handles RPC error response" do
      Req.Test.expect(MultiChainRpcPrism, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "error" => %{"code" => -32601, "message" => "Method not found"}})
      end)

      input = %{chain: "ethereum", method: "invalid_method", params: []}
      assert {:error, error} = MultiChainRpcPrism.handler(input, nil)
      assert error =~ "RPC error"
    end

    test "handles unsupported chain" do
      input = %{chain: "unsupported_chain", method: "eth_blockNumber"}
      assert {:error, "Unsupported chain: unsupported_chain"} = MultiChainRpcPrism.handler(input, nil)
    end
  end
end
