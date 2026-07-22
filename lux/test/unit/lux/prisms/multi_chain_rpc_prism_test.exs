defmodule Lux.Prisms.MultiChainRpcPrismTest do
  use UnitAPICase, async: false

  alias Lux.Prisms.MultiChainRpcPrism

  setup do
    Req.Test.verify_on_exit!()
    existing_req_options = Application.get_env(:lux, :req_options)
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
        {:ok, body, _} = Plug.Conn.read_body(conn)
        json = Jason.decode!(body)
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

    test "handles rate limiting (429) by retrying and eventually returning error" do
      Req.Test.expect(MultiChainRpcPrism, 4, fn conn ->
        Plug.Conn.send_resp(conn, 429, "Too Many Requests")
      end)

      input = %{chain: "ethereum", method: "eth_blockNumber", params: []}
      assert {:error, :rate_limited} = MultiChainRpcPrism.handler(input, nil)
    end

    test "handles provider failure (500) by falling back to next provider" do
      # Mock the first request to fail with 500, and second to succeed
      Process.put(:req_count, 0)
      Req.Test.expect(MultiChainRpcPrism, 2, fn conn ->
        count = Process.get(:req_count)
        Process.put(:req_count, count + 1)

        if count == 0 do
          Plug.Conn.send_resp(conn, 500, "Internal Server Error")
        else
          Req.Test.json(conn, %{"jsonrpc" => "2.0", "result" => "0x1b5"})
        end
      end)

      input = %{chain: "ethereum", method: "eth_blockNumber", params: []}
      assert {:ok, %{result: "0x1b5", chain: "ethereum"}} = MultiChainRpcPrism.handler(input, nil)
    end

    test "handles malformed response" do
      Req.Test.expect(MultiChainRpcPrism, 2, fn conn ->
        Plug.Conn.send_resp(conn, 200, "not json")
      end)

      input = %{chain: "ethereum", method: "eth_blockNumber", params: []}
      assert {:error, :all_providers_failed} = MultiChainRpcPrism.handler(input, nil)
    end

    test "handles unsupported chain" do
      input = %{chain: "unsupported_chain", method: "eth_blockNumber"}
      assert {:error, "Unsupported chain: unsupported_chain"} = MultiChainRpcPrism.handler(input, nil)
    end
  end
end
