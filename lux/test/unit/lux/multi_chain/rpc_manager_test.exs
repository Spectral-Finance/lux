defmodule Lux.MultiChain.RpcManagerTest do
  use UnitAPICase, async: false

  alias Lux.MultiChain.Cache
  alias Lux.MultiChain.RpcManager

  setup do
    Cache.init()
    Cache.clear_all()
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "call/4" do
    test "makes a successful RPC call" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert decoded["method"] == "eth_blockNumber"
        assert decoded["jsonrpc"] == "2.0"

        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => "0x112A880"})
      end)

      Application.put_env(:lux, :multi_chain, %{
        rpc_endpoints: %{ethereum: ["http://localhost:8545"]}
      })

      assert {:ok, "0x112A880"} = RpcManager.call(:ethereum, "eth_blockNumber", [])
    end

    test "handles RPC error responses" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "error" => %{"code" => -32_600, "message" => "Invalid request"}
        })
      end)

      Application.put_env(:lux, :multi_chain, %{
        rpc_endpoints: %{ethereum: ["http://localhost:8545"]}
      })

      assert {:error, "RPC error (-32600): Invalid request"} =
               RpcManager.call(:ethereum, "eth_blockNumber", [])
    end

    test "caches results when cache_ttl is specified" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => "0x100"})
      end)

      Application.put_env(:lux, :multi_chain, %{
        rpc_endpoints: %{ethereum: ["http://localhost:8545"]}
      })

      assert {:ok, "0x100"} =
               RpcManager.call(:ethereum, "eth_blockNumber", [], cache_ttl: 60_000)

      # Second call should use cache (no additional Req.Test.expect needed)
      assert {:ok, "0x100"} =
               RpcManager.call(:ethereum, "eth_blockNumber", [], cache_ttl: 60_000)
    end
  end

  describe "batch_call/3" do
    test "makes a successful batch RPC call" do
      Req.Test.expect(Lux.Lens, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)
        assert is_list(decoded)
        assert length(decoded) == 2

        Req.Test.json(conn, [
          %{"jsonrpc" => "2.0", "id" => 1, "result" => "0x112A880"},
          %{"jsonrpc" => "2.0", "id" => 2, "result" => "0x3B9ACA00"}
        ])
      end)

      Application.put_env(:lux, :multi_chain, %{
        rpc_endpoints: %{ethereum: ["http://localhost:8545"]}
      })

      assert {:ok, results} =
               RpcManager.batch_call(:ethereum, [
                 {"eth_blockNumber", []},
                 {"eth_gasPrice", []}
               ])

      assert [{:ok, "0x112A880"}, {:ok, "0x3B9ACA00"}] = results
    end
  end

  describe "get_endpoints/1" do
    test "returns configured endpoints" do
      Application.put_env(:lux, :multi_chain, %{
        rpc_endpoints: %{ethereum: ["http://endpoint1", "http://endpoint2"]}
      })

      assert ["http://endpoint1", "http://endpoint2"] = RpcManager.get_endpoints(:ethereum)
    end

    test "returns empty list when no endpoints configured" do
      Application.put_env(:lux, :multi_chain, %{rpc_endpoints: %{}})
      assert [] = RpcManager.get_endpoints(:unknown_chain)
    end
  end

  describe "get_endpoint/1" do
    test "returns primary endpoint" do
      Application.put_env(:lux, :multi_chain, %{
        rpc_endpoints: %{ethereum: ["http://primary", "http://backup"]}
      })

      assert "http://primary" = RpcManager.get_endpoint(:ethereum)
    end

    test "falls back to default public endpoints" do
      Application.put_env(:lux, :multi_chain, %{rpc_endpoints: %{}})

      assert "https://eth.llamarpc.com" = RpcManager.get_endpoint(:ethereum)
      assert "https://polygon.llamarpc.com" = RpcManager.get_endpoint(:polygon)
      assert "https://bsc-dataseed.binance.org" = RpcManager.get_endpoint(:bsc)
      assert "https://arb1.arbitrum.io/rpc" = RpcManager.get_endpoint(:arbitrum)
      assert "https://mainnet.optimism.io" = RpcManager.get_endpoint(:optimism)
      assert "https://mainnet.base.org" = RpcManager.get_endpoint(:base)
      assert "https://api.avax.network/ext/bc/C/rpc" = RpcManager.get_endpoint(:avalanche)
    end
  end
end
