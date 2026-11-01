defmodule Lux.Web3.EventMonitor.FilterEngineTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.EventMonitor.FilterEngine
  alias Lux.Web3.EventMonitor.Schemas.{MonitoredEvent, Subscription, FilterPattern}

  setup do
    event = %MonitoredEvent{
      id: "evt_1",
      subscription_id: "sub_1",
      chain_id: 1,
      chain: :ethereum,
      contract_address: "0xdac17f958d2ee523a2206206994597c13d831ec7",
      event_name: "Transfer",
      tx_hash: "0x123",
      block_number: 100,
      topics: ["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"],
      decoded_params: %{
        from: "0x1111111111111111111111111111111111111111",
        to: "0x2222222222222222222222222222222222222222",
        value: 50_000
      }
    }

    sub = %Subscription{
      id: "sub_1",
      chain_id: 1,
      chain: :ethereum,
      contract_address: "0xdac17f958d2ee523a2206206994597c13d831ec7",
      topic0: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
      filter_pattern: %{}
    }

    %{event: event, sub: sub}
  end

  describe "matches?/2" do
    test "matches when all criteria pass", %{event: event, sub: sub} do
      assert FilterEngine.matches?(event, sub) == true
    end

    test "rejects when contract address does not match", %{event: event, sub: sub} do
      sub_diff = %{sub | contract_address: "0x3333333333333333333333333333333333333333"}
      assert FilterEngine.matches?(event, sub_diff) == false
    end

    test "evaluates min_value threshold", %{event: event, sub: sub} do
      sub_pass = %{sub | filter_pattern: %FilterPattern{min_value: 40_000}}
      sub_fail = %{sub | filter_pattern: %FilterPattern{min_value: 100_000}}

      assert FilterEngine.matches?(event, sub_pass) == true
      assert FilterEngine.matches?(event, sub_fail) == false
    end

    test "evaluates address whitelist", %{event: event, sub: sub} do
      sub_pass = %{
        sub
        | filter_pattern: %FilterPattern{
            to_whitelist: ["0x2222222222222222222222222222222222222222"]
          }
      }

      sub_fail = %{
        sub
        | filter_pattern: %FilterPattern{
            to_whitelist: ["0x9999999999999999999999999999999999999999"]
          }
      }

      assert FilterEngine.matches?(event, sub_pass) == true
      assert FilterEngine.matches?(event, sub_fail) == false
    end

    test "evaluates address blacklist", %{event: event, sub: sub} do
      sub_blacklisted = %{
        sub
        | filter_pattern: %FilterPattern{
            address_blacklist: ["0x1111111111111111111111111111111111111111"]
          }
      }

      assert FilterEngine.matches?(event, sub_blacklisted) == false
    end
  end
end
