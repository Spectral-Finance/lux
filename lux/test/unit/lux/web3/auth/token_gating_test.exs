defmodule Lux.Web3.Auth.TokenGatingTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Auth.TokenGating

  @addr "0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5"
  @token_contract "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
  @nft_contract "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d"

  describe "evaluate_gate/3 with :all combinator" do
    test "passes when all balance conditions are satisfied" do
      rule1 = TokenGating.erc20_rule(@token_contract, 500)
      rule2 = TokenGating.erc721_rule(@nft_contract)

      balances = %{
        @token_contract => 1000,
        @nft_contract => 1
      }

      assert {:ok, %{allowed: true, matched_rules: matched}} =
               TokenGating.evaluate_gate(@addr, %{operator: :all, rules: [rule1, rule2]}, balances)

      assert length(matched) == 2
    end

    test "fails when at least one condition is unsatisfied" do
      rule1 = TokenGating.erc20_rule(@token_contract, 500)
      rule2 = TokenGating.erc721_rule(@nft_contract)

      balances = %{
        @token_contract => 100,
        @nft_contract => 1
      }

      assert {:error, :access_denied, %{allowed: false, missing_rules: missing}} =
               TokenGating.evaluate_gate(@addr, %{operator: :all, rules: [rule1, rule2]}, balances)

      assert length(missing) == 1
    end
  end

  describe "evaluate_gate/3 with :any combinator" do
    test "passes when at least one condition is satisfied" do
      rule1 = TokenGating.erc20_rule(@token_contract, 500)
      rule2 = TokenGating.erc721_rule(@nft_contract)

      balances = %{
        @token_contract => 100,
        @nft_contract => 1
      }

      assert {:ok, %{allowed: true}} =
               TokenGating.evaluate_gate(@addr, %{operator: :any, rules: [rule1, rule2]}, balances)
    end
  end

  describe "dynamic provider function" do
    test "uses custom balance fetching callback" do
      rule = TokenGating.native_rule(1_000_000_000_000_000_000)

      provider = fn r, _addr ->
        if r.type == :native, do: 2_000_000_000_000_000_000, else: 0
      end

      assert {:ok, %{allowed: true}} = TokenGating.evaluate_gate(@addr, rule, provider)
    end
  end
end
