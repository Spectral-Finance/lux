defmodule Lux.Web3.Curve.RewardsTest do
  @moduledoc false
  use UnitCase, async: true

  alias Lux.Web3.Curve.Rewards

  @crv_price 2_000_000_000_000_000_000
  @gas 100_000_000_000_000_000

  describe "happy path: CRV rewards optimisation" do
    test "should_claim?/3 recommends a claim when value exceeds gas" do
      assert {:ok, result} = Rewards.should_claim?(100, @crv_price, @gas)
      assert result.value == 200_000_000_000_000_000_000
      assert result.net == 199_900_000_000_000_000_000
      assert result.decision == :claim
    end
  end

  describe "null input: handled with a typed validation error" do
    test "should_claim?/3 rejects null inputs" do
      assert {:error, :invalid_reward_input} = Rewards.should_claim?(nil, @crv_price, @gas)
      assert {:error, :invalid_reward_input} = Rewards.should_claim?(100, nil, @gas)
      assert {:error, :invalid_reward_input} = Rewards.should_claim?(100, @crv_price, nil)
    end
  end

  describe "empty input: rejected with a clear diagnostic" do
    test "a zero claimable balance yields a skip decision" do
      assert {:ok, %{value: 0, decision: :skip}} = Rewards.should_claim?(0, @crv_price, @gas)
    end

    test "an empty (undefined) reward input is refused" do
      assert {:error, :invalid_reward_input} = Rewards.should_claim?("", @crv_price, @gas)
    end
  end

  describe "boundary limits: strict half-open evaluation" do
    test "claiming is skipped when value equals gas at the threshold" do
      assert {:ok, %{value: 100, gas_cost: 100, net: 0, decision: :skip}} =
               Rewards.should_claim?(1, 100, 100)
    end

    test "claiming is recommended one wei above the threshold" do
      assert {:ok, %{value: 101, net: 1, decision: :claim}} =
               Rewards.should_claim?(1, 101, 100)
    end
  end

  describe "negative: malformed data is refused" do
    test "a negative claimable balance is refused" do
      assert {:error, :invalid_reward_input} = Rewards.should_claim?(-1, @crv_price, @gas)
    end

    test "a negative gas cost is refused" do
      assert {:error, :invalid_reward_input} = Rewards.should_claim?(1, @crv_price, -1)
    end
  end

  describe "concurrency: simultaneous reward evaluation" do
    test "concurrent evaluations are consistent" do
      results =
        1..20
        |> Enum.map(fn _ ->
          Task.async(fn -> Rewards.should_claim?(100, @crv_price, @gas) end)
        end)
        |> Task.await_many(30_000)

      assert length(Enum.uniq(results)) == 1
    end
  end
end
