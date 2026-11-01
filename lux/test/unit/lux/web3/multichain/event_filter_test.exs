defmodule Lux.Web3.Multichain.EventFilterTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Multichain.EventFilter
  alias Lux.Web3.Multichain.Schemas.{Event, TokenTransfer}

  describe "Multi-Chain Event Filter & Parser (#74)" do
    setup do
      transfer_event = %Event{
        chain_id: 1,
        chain: :ethereum,
        contract_address: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        event_name: "Transfer",
        block_number: 10_000,
        tx_hash: "0xabcdef123",
        log_index: 0,
        topics: [
          "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
          "0x0000000000000000000000001111111111111111111111111111111111111111",
          "0x0000000000000000000000002222222222222222222222222222222222222222"
        ],
        data: "0x00000000000000000000000000000000000000000000000000000000000f4240",
        decoded_params: %{}
      }

      %{transfer_event: transfer_event}
    end

    test "matches event by contract address and topic", %{transfer_event: ev} do
      assert EventFilter.matches?(ev, %{
               contract_address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
             })

      assert EventFilter.matches?(ev, %{event_type: :erc20_transfer})

      refute EventFilter.matches?(ev, %{
               contract_address: "0x0000000000000000000000000000000000000000"
             })

      refute EventFilter.matches?(ev, %{event_type: :uniswap_v2_swap})
    end

    test "matches event by from and to addresses in topics", %{transfer_event: ev} do
      assert EventFilter.matches?(ev, %{
               from_address: "0x1111111111111111111111111111111111111111"
             })

      assert EventFilter.matches?(ev, %{
               to_address: "0x2222222222222222222222222222222222222222"
             })

      refute EventFilter.matches?(ev, %{
               from_address: "0x9999999999999999999999999999999999999999"
             })
    end

    test "parses token transfer event into TokenTransfer struct", %{transfer_event: ev} do
      assert {:ok, %TokenTransfer{} = transfer} = EventFilter.parse_token_transfer(ev)
      assert transfer.token_address == "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
      assert transfer.token_standard == :erc20
      assert transfer.from == "0x1111111111111111111111111111111111111111"
      assert transfer.to == "0x2222222222222222222222222222222222222222"
      assert transfer.amount == 1_000_000
    end
  end
end
