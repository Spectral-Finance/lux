defmodule Lux.Web3.MultiChain.RPCClientTest do
  use UnitAPICase, async: true

  alias Lux.Web3.MultiChain.RPCClient

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "call/4" do
    test "sends JSON-RPC requests to a configured chain" do
      Req.Test.stub(__MODULE__, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body = Jason.decode!(body)

        assert body["jsonrpc"] == "2.0"
        assert body["method"] == "eth_blockNumber"
        assert body["params"] == []

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"jsonrpc" => "2.0", "id" => 1, "result" => "0x10"}))
      end)

      assert RPCClient.call(:ethereum, "eth_blockNumber", [], %{
               rpc_urls: %{ethereum: "https://eth.example"},
               plug: {Req.Test, __MODULE__}
             }) == {:ok, "0x10"}
    end

    test "normalizes rpc errors" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{
          "jsonrpc" => "2.0",
          "id" => 1,
          "error" => %{"code" => -32601, "message" => "Method not found"}
        }))
      end)

      assert {:error, {:rpc_error, %{"code" => -32601}}} =
               RPCClient.call(:ethereum, "missing_method", [], %{
                 rpc_urls: %{ethereum: "https://eth.example"},
                 plug: {Req.Test, __MODULE__}
               })
    end

    test "retries retryable http responses" do
      test_pid = self()
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      Req.Test.stub(__MODULE__, fn conn ->
        attempt = Agent.get_and_update(counter, fn value -> {value, value + 1} end)

        if attempt == 0 do
          conn
          |> Plug.Conn.put_resp_header("retry-after", "1")
          |> Plug.Conn.send_resp(429, "rate limited")
        else
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, Jason.encode!(%{"jsonrpc" => "2.0", "id" => 1, "result" => "0x20"}))
        end
      end)

      assert RPCClient.call(:polygon, "eth_blockNumber", [], %{
               rpc_urls: %{polygon: "https://polygon.example"},
               max_retries: 1,
               sleep: fn delay_ms -> send(test_pid, {:slept, delay_ms}) end,
               plug: {Req.Test, __MODULE__}
             }) == {:ok, "0x20"}

      assert_received {:slept, 1000}
      assert Agent.get(counter, & &1) == 2
    end
  end
end
