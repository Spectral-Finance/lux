defmodule Lux.Integrations.PancakeSwap.ClientTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.PancakeSwap
  alias Lux.Integrations.PancakeSwap.Client
  alias Test.Support.PancakeSwapRpc

  @owner "0x00000000000000000000000000000000000000aa"
  @token "0x00000000000000000000000000000000000000bb"
  @spender "0x00000000000000000000000000000000000000cc"

  setup do
    {:ok, chain} = PancakeSwap.chain("bsc")
    %{chain: chain}
  end

  describe "eth_call/6" do
    test "encodes the call and decodes the result", %{chain: chain} do
      PancakeSwapRpc.stub(%{"balanceOf(address)" => {["uint256"], [12_345]}})

      assert Client.eth_call(chain, @token, "balanceOf(address)", [@owner], ["uint256"]) ==
               {:ok, [12_345]}

      expected_data = PancakeSwapRpc.calldata("balanceOf(address)", [@owner])
      assert_received {:rpc_call, @token, ^expected_data}
    end

    test "posts to the chain's RPC endpoint unless overridden", %{chain: chain} do
      Req.Test.stub(PancakeSwapClientMock, fn conn ->
        send(self(), {:host, conn.host, conn.request_path})

        PancakeSwapRpc.json(conn, 200, %{
          jsonrpc: "2.0",
          id: 1,
          result: "0x" <> String.duplicate("00", 32)
        })
      end)

      assert {:ok, [0]} = Client.eth_call(chain, @token, "totalSupply()", [], ["uint256"])
      assert_received {:host, "bsc-dataseed.binance.org", _path}

      assert {:ok, [0]} =
               Client.eth_call(chain, @token, "totalSupply()", [], ["uint256"],
                 rpc_url: "https://rpc.example.test/custom"
               )

      assert_received {:host, "rpc.example.test", "/custom"}
    end

    test "returns JSON-RPC errors", %{chain: chain} do
      PancakeSwapRpc.stub(%{})

      assert Client.eth_call(chain, @token, "totalSupply()", [], ["uint256"]) ==
               {:error, {:rpc_error, -32_000, "execution reverted"}}
    end

    test "returns an error for an empty result (call to a non contract)", %{chain: chain} do
      Req.Test.stub(PancakeSwapClientMock, fn conn ->
        PancakeSwapRpc.json(conn, 200, %{jsonrpc: "2.0", id: 1, result: "0x"})
      end)

      assert Client.eth_call(chain, @token, "totalSupply()", [], ["uint256"]) ==
               {:error, :empty_result}
    end

    test "returns HTTP errors", %{chain: chain} do
      Req.Test.stub(PancakeSwapClientMock, fn conn ->
        PancakeSwapRpc.json(conn, 500, %{"message" => "boom"})
      end)

      assert Client.eth_call(chain, @token, "totalSupply()", [], ["uint256"]) ==
               {:error, {:http_error, 500, %{"message" => "boom"}}}
    end

    test "returns transport errors", %{chain: chain} do
      Req.Test.stub(PancakeSwapClientMock, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, %Req.TransportError{reason: :econnrefused}} =
               Client.eth_call(chain, @token, "totalSupply()", [], ["uint256"])
    end

    test "returns an error for arguments that cannot be encoded", %{chain: chain} do
      assert {:error, message} =
               Client.eth_call(chain, @token, "balanceOf(address)", ["nope"], ["uint256"])

      assert message =~ "invalid address"
    end
  end

  describe "allowance/5" do
    test "reads the ERC-20 allowance", %{chain: chain} do
      PancakeSwapRpc.stub(%{"allowance(address,address)" => {["uint256"], [777]}})

      assert Client.allowance(chain, @token, @owner, @spender) == {:ok, 777}

      expected_data = PancakeSwapRpc.calldata("allowance(address,address)", [@owner, @spender])
      assert_received {:rpc_call, @token, ^expected_data}
    end
  end

  describe "gas_price/2" do
    test "parses the hex quantity", %{chain: chain} do
      PancakeSwapRpc.stub(%{"eth_gasPrice" => "0x3b9aca00"})
      assert Client.gas_price(chain) == {:ok, 1_000_000_000}
    end

    test "returns RPC errors", %{chain: chain} do
      Req.Test.stub(PancakeSwapClientMock, fn conn ->
        PancakeSwapRpc.json(conn, 200, %{
          jsonrpc: "2.0",
          id: 1,
          error: %{code: -32_005, message: "limit"}
        })
      end)

      assert Client.gas_price(chain) == {:error, {:rpc_error, -32_005, "limit"}}
    end
  end
end
