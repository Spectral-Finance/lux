defmodule Lux.Web3.MultiChain.AggregatorTest do
  use UnitAPICase, async: true

  alias Lux.Web3.MultiChain.Aggregator

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "latest_blocks/2" do
    test "fetches and normalizes latest blocks across chains" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      Req.Test.stub(__MODULE__, fn conn ->
        attempt = Agent.get_and_update(counter, fn value -> {value, value + 1} end)
        result = if attempt == 0, do: "0x10", else: "0x20"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(%{"jsonrpc" => "2.0", "id" => 1, "result" => result}))
      end)

      assert {:ok, blocks} =
               Aggregator.latest_blocks([:ethereum, :polygon], %{
                 rpc_urls: %{
                   ethereum: "https://eth.example",
                   polygon: "https://polygon.example"
                 },
                 plug: {Req.Test, __MODULE__}
               })

      assert blocks == [
               %{chain: :ethereum, chain_id: 1, block_number: 16},
               %{chain: :polygon, chain_id: 137, block_number: 32}
             ]
    end
  end

  describe "event_filter/1" do
    test "normalizes chains, addresses, topics, and block range" do
      address = "0xABCDEFabcdefABCDEFabcdefABCDEFabcdefABCD"

      assert {:ok, filter} =
               Aggregator.event_filter(%{
                 chains: ["ethereum", 137],
                 addresses: [address],
                 topics: ["0xtopic"],
                 from_block: "0x1",
                 to_block: "latest"
               })

      assert filter.chains == [:ethereum, :polygon]
      assert filter.address == [String.downcase(address)]
      assert filter.topics == ["0xtopic"]
      assert filter.from_block == "0x1"
      assert filter.to_block == "latest"
    end

    test "rejects invalid addresses" do
      assert Aggregator.event_filter(%{chains: [:ethereum], addresses: ["0x123"]}) ==
               {:error, :invalid_address}
    end
  end

  describe "parse_quantity/1" do
    test "parses rpc quantities" do
      assert Aggregator.parse_quantity("0xff") == {:ok, 255}
      assert Aggregator.parse_quantity(42) == {:ok, 42}
      assert Aggregator.parse_quantity("not-hex") == {:error, :invalid_quantity}
    end
  end
end
