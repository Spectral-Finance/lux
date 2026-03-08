defmodule Lux.Integrations.Web3.Chain.RpcClientTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Web3.Chain.RpcClient

  setup do
    Req.Test.stub(Lux.Web3.RpcOk, fn conn ->
      Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => "0x1234"})
    end)

    Req.Test.stub(Lux.Web3.RpcError, fn conn ->
      Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "error" => %{"code" => -32600, "message" => "Invalid"}})
    end)

    Req.Test.stub(Lux.Web3.RpcBatch, fn conn ->
      Req.Test.json(conn, [
        %{"jsonrpc" => "2.0", "id" => 1, "result" => "0xaaa"},
        %{"jsonrpc" => "2.0", "id" => 2, "result" => "0xbbb"}
      ])
    end)

    :ok
  end

  test "successful call" do
    assert {:ok, "0x1234"} = RpcClient.call("eth_blockNumber", [], rpc_url: "https://test", plug: {Req.Test, Lux.Web3.RpcOk})
  end

  test "error response" do
    assert {:error, %{"code" => -32600}} = RpcClient.call("eth_blockNumber", [], rpc_url: "https://test", plug: {Req.Test, Lux.Web3.RpcError})
  end

  test "batch calls" do
    assert {:ok, results} = RpcClient.batch(
      [{"eth_blockNumber", []}, {"eth_gasPrice", []}],
      rpc_url: "https://test", plug: {Req.Test, Lux.Web3.RpcBatch}
    )

    assert [{:ok, "0xaaa"}, {:ok, "0xbbb"}] = results
  end

  test "raises without rpc_url" do
    assert_raise RuntimeError, ~r/RPC URL/, fn ->
      RpcClient.call("eth_blockNumber", [], [])
    end
  end
end
