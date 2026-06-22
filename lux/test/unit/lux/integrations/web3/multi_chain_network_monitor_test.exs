defmodule Lux.Integrations.Web3.MultiChain.NetworkMonitorTest do
  use ExUnit.Case, async: false

  alias Lux.Integrations.Web3.MultiChain.NetworkMonitor
  alias Lux.Integrations.Web3.MultiChain.Storage

  setup_all do
    # Start a simple Bandit plug to act as our fake HTTP JSON-RPC endpoint
    {:ok, pid} = Bandit.start_link(plug: __MODULE__.FakeRPC, port: 4001)
    
    on_exit(fn -> 
      Process.exit(pid, :kill) 
    end)
    :ok
  end

  setup do
    Storage.clear()
    start_supervised!(Lux.Integrations.Web3.MultiChain.NetworkMonitorTest.FakeRPC.State)
    Agent.update(__MODULE__.FakeRPC.State, fn _ -> %{request_count: 0} end)
    :ok
  end

  defmodule FakeRPC do
    use Plug.Router

    plug :match
    plug :dispatch

    defmodule State do
      use Agent
      def start_link(_), do: Agent.start_link(fn -> %{request_count: 0} end, name: __MODULE__)
    end

    post "/" do
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      payload = Jason.decode!(body)
      
      Agent.update(State, fn s -> Map.update(s, :request_count, 1, &(&1 + 1)) end)
      
      response = 
        case payload["method"] do
          "eth_getBlockByNumber" ->
            case payload["params"] do
              ["latest", _] ->
                # Return block 10
                %{
                  "jsonrpc" => "2.0",
                  "id" => payload["id"],
                  "result" => %{
                    "number" => "0xa", # 10
                    "hash" => "0xabc",
                    "timestamp" => "0x123",
                    "transactions" => [
                      %{"hash" => "0xbeef"}
                    ]
                  }
                }
              ["0x9", _] ->
                # Backfill block 9
                %{
                  "jsonrpc" => "2.0",
                  "id" => payload["id"],
                  "result" => %{
                    "number" => "0x9",
                    "hash" => "0xdef",
                    "timestamp" => "0x122",
                    "transactions" => []
                  }
                }
              _ ->
                %{
                  "jsonrpc" => "2.0",
                  "id" => payload["id"],
                  "result" => nil
                }
            end
          _ -> 
            %{
              "jsonrpc" => "2.0",
              "error" => "Method not found"
            }
        end
        
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(response))
    end
    
    match _ do
      send_resp(conn, 404, "Not Found")
    end
  end

  test "network monitor polls latest block, inserts transactions, and backfills" do
    # We set last_block to 8, so when it fetches latest (10), it should backfill 9.
    {:ok, monitor_pid} = GenServer.start_link(
      NetworkMonitor,
      %{chain_id: 1337, rpc_url: "http://localhost:4001/", mode: :http, retries: 0, last_block: 8}
    )

    # Wait for the poll to happen (poll happens almost immediately via schedule_poll)
    Process.sleep(500)

    # Verify latest block (10) was inserted
    blocks = Storage.get_latest_blocks()
    assert blocks[1337]["number"] == "0xa"
    
    # Verify transaction 0xbeef from block 10 was inserted
    txs = Storage.get_transactions(1337)
    assert length(txs) > 0
    assert Enum.any?(txs, fn t -> t.hash == "0xbeef" end)
    
    # The storage should contain both block 10 AND the backfilled block 9.
    all_blocks = :ets.match_object(:multi_chain_storage, {{:block, 1337, :_}, :_, :_})
    assert length(all_blocks) == 2
    
    # Verify requests were made: 1 for latest, 1 for backfill block 9
    req_count = Agent.get(FakeRPC.State, &(&1.request_count))
    assert req_count >= 2
    
    # Cleanup
    GenServer.stop(monitor_pid)
  end
end
