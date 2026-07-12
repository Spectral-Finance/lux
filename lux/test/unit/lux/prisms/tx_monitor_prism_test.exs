defmodule Lux.Prisms.TxMonitorPrismTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.TxMonitorPrism
  alias Lux.Prisms.MultiChainRpcPrism

  setup do
    Req.Test.verify_on_exit!()
    Application.put_env(:lux, :req_options, plug: {Req.Test, MultiChainRpcPrism})
    :ok
  end

  describe "handler/2" do
    test "returns success when receipt status is 0x1" do
      Req.Test.expect(MultiChainRpcPrism, fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        json = Jason.decode!(body)
        assert json["method"] == "eth_getTransactionReceipt"

        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => json["id"],
          "result" => %{"status" => "0x1", "transactionHash" => "0x123"}
        })
      end)

      input = %{chain: "ethereum", tx_hash: "0x123"}
      assert {:ok, %{status: "success", receipt: %{"status" => "0x1"}}} = TxMonitorPrism.handler(input, nil)
    end

    test "returns failed when receipt status is 0x0" do
      Req.Test.expect(MultiChainRpcPrism, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "result" => %{"status" => "0x0", "transactionHash" => "0x123"}
        })
      end)

      input = %{chain: "ethereum", tx_hash: "0x123"}
      assert {:ok, %{status: "failed", receipt: %{"status" => "0x0"}}} = TxMonitorPrism.handler(input, nil)
    end

    test "returns pending when receipt is nil" do
      Req.Test.expect(MultiChainRpcPrism, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "result" => nil
        })
      end)

      input = %{chain: "ethereum", tx_hash: "0x123"}
      assert {:ok, %{status: "pending", receipt: nil}} = TxMonitorPrism.handler(input, nil)
    end

    test "handles string-keyed inputs" do
      Req.Test.expect(MultiChainRpcPrism, fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        json = Jason.decode!(body)
        assert json["method"] == "eth_getTransactionReceipt"

        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => json["id"],
          "result" => %{"status" => "0x1", "transactionHash" => "0x123"}
        })
      end)

      input = %{"chain" => "ethereum", "tx_hash" => "0x123"}
      assert {:ok, %{status: "success", receipt: %{"status" => "0x1"}}} = TxMonitorPrism.handler(input, nil)
    end
  end
end
