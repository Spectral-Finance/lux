defmodule Lux.Integrations.PancakeSwap.Test do
  use ExUnit.Case, async: true
  @moduletag :unit

  alias Lux.Integrations.PancakeSwap
  alias Lux.Integrations.PancakeSwap.{Client, Pools, Yield}

  describe "PancakeSwap client" do
    test "chain_slug/1 maps known chains" do
      assert Client.chain_slug(56) == "bsc"
      assert Client.chain_slug(1) == "eth"
      assert Client.chain_slug(42161) == "arbitrum"
      assert Client.chain_slug(99999) == "bsc"
    end
  end

  describe "get_token_info/2" do
    @tag :skip
    test "fetches BNB token info on BSC" do
      assert {:ok, token} = PancakeSwap.get_token_info(:BNB, 56)
      assert token["symbol"] == "BNB"
    end
  end

  describe "get_price/3" do
    @tag :skip
    test "gets BNB/USDT price" do
      assert {:ok, price} = PancakeSwap.get_price(:BNB, :USDT)
      assert is_float(price)
      assert price > 0
    end
  end

  describe "Pools module" do
    test "calculate_apy returns valid format" do
      pool = %{
        "totalValueLockedUSD" => "1000000",
        "volumeUSD" => "100000",
        "feeTier" => "500"
      }

      apy = Pools.calculate_apy(pool)
      assert is_float(apy)
    end

    test "list_pools returns error for unknown chain" do
      result = Pools.list_pools(chain_id: 99999)
      assert {:error, _} = result
    end

    test "get_pool returns error for non-existent pool" do
      result = Pools.get_pool("0xnope")
      assert {:error, _} = result
    end
  end

  describe "Yield module" do
    test "track_position returns error for non-existent pool" do
      result = Yield.track_position(pool_id: "0xnonexistent", staked_amount: 100.0)
      assert {:error, _} = result
    end

    test "calculate_rewards returns error for non-existent pool" do
      result = Yield.calculate_rewards(pool_id: "0xnonexistent", staked_amount: 100.0)
      assert {:error, _} = result
    end

    test "simulate_auto_compound returns error for non-existent pool" do
      result = Yield.simulate_auto_compound(pool_id: "0xnon", principal: 1000.0)
      assert {:error, _} = result
    end

    test "top_farms returns error with bad chain" do
      result = Yield.top_farms(chain_id: 99999)
      assert {:error, _} = result
    end

    test "assess_risk returns error for non-existent pool" do
      result = Yield.assess_risk("0xnonexistent_pool")
      assert {:error, _} = result
    end

    test "swappot quote returns error for invalid token" do
      {:ok, tokens} = Client.fetch_token_list(56) rescue {:error, "token list not available"}

      case tokens do
        {:error, _} -> :ok
        _ -> assert {:error, _} = PancakeSwap.get_swap_quote(
          token_in: :ZZZZZZ,
          token_out: :YYYYYY,
          amount: "100"
        )
      end
    end
  end

  describe "configuration" do
    test "chain_id/0 returns default" do
      assert PancakeSwap.chain_id() == 56
    end

    test "base_url/0 returns configured URL" do
      assert PancakeSwap.base_url() == "https://tokens.pancakeswap.finance"
    end
  end
end
