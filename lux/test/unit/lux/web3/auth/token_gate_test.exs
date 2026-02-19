defmodule Lux.Web3.Auth.TokenGateTest do
  @moduledoc """
  Tests for the TokenGate module covering rule building,
  access checking with AND/OR logic, and balance verification.
  """

  use UnitCase, async: true

  alias Lux.Web3.Auth.TokenGate

  @test_address "0x71C7656EC7ab88b098defB751B7401B5f6d8976F"
  @usdc_contract "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
  @nft_contract "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D"

  describe "build_rule/1" do
    test "builds a valid ERC-20 rule" do
      assert {:ok, rule} =
               TokenGate.build_rule(%{
                 contract: @usdc_contract,
                 chain_id: 1,
                 type: :erc20,
                 min_balance: 1000,
                 role: :usdc_holder
               })

      assert rule.contract == @usdc_contract
      assert rule.chain_id == 1
      assert rule.type == :erc20
      assert rule.min_balance == 1000
      assert rule.role == :usdc_holder
    end

    test "builds a valid ERC-721 rule" do
      assert {:ok, rule} =
               TokenGate.build_rule(%{
                 contract: @nft_contract,
                 chain_id: 1,
                 type: :erc721,
                 min_balance: 1,
                 token_id: 42
               })

      assert rule.type == :erc721
      assert rule.token_id == 42
    end

    test "builds a valid ERC-1155 rule" do
      assert {:ok, rule} =
               TokenGate.build_rule(%{
                 contract: @nft_contract,
                 chain_id: 1,
                 type: :erc1155,
                 min_balance: 5
               })

      assert rule.type == :erc1155
    end

    test "defaults type to :erc20" do
      assert {:ok, rule} =
               TokenGate.build_rule(%{contract: @usdc_contract, chain_id: 1})

      assert rule.type == :erc20
    end

    test "defaults min_balance to 1" do
      assert {:ok, rule} =
               TokenGate.build_rule(%{contract: @usdc_contract, chain_id: 1})

      assert rule.min_balance == 1
    end

    test "rejects missing contract" do
      assert {:error, "contract address is required"} =
               TokenGate.build_rule(%{chain_id: 1})
    end

    test "rejects invalid contract address" do
      assert {:error, "invalid contract address format"} =
               TokenGate.build_rule(%{contract: "not-an-address", chain_id: 1})
    end

    test "rejects missing chain_id" do
      assert {:error, "chain_id is required"} =
               TokenGate.build_rule(%{contract: @usdc_contract})
    end

    test "rejects invalid token type" do
      assert {:error, _} =
               TokenGate.build_rule(%{
                 contract: @usdc_contract,
                 chain_id: 1,
                 type: :invalid
               })
    end
  end

  describe "check_access/3 (AND logic)" do
    test "passes when all rules are met" do
      rules = [
        %{contract: @usdc_contract, chain_id: 1, type: :erc20, min_balance: 100, token_id: nil, role: :usdc_holder},
        %{contract: @nft_contract, chain_id: 1, type: :erc721, min_balance: 1, token_id: nil, role: :nft_holder}
      ]

      checker = fn _addr, contract, _chain ->
        case contract do
          @usdc_contract -> {:ok, 500}
          @nft_contract -> {:ok, 2}
        end
      end

      assert {:ok, result} = TokenGate.check_access(@test_address, rules, checker)
      assert result.passed == true
      assert :usdc_holder in result.roles
      assert :nft_holder in result.roles
    end

    test "fails when any rule is not met" do
      rules = [
        %{contract: @usdc_contract, chain_id: 1, type: :erc20, min_balance: 1000, token_id: nil, role: :usdc_holder},
        %{contract: @nft_contract, chain_id: 1, type: :erc721, min_balance: 1, token_id: nil, role: :nft_holder}
      ]

      checker = fn _addr, contract, _chain ->
        case contract do
          @usdc_contract -> {:ok, 50}  # Below minimum
          @nft_contract -> {:ok, 2}
        end
      end

      assert {:ok, result} = TokenGate.check_access(@test_address, rules, checker)
      assert result.passed == false
      # Only NFT role should be present (the one that passed)
      assert :nft_holder in result.roles
      refute :usdc_holder in result.roles
    end

    test "returns error when balance checker fails" do
      rules = [
        %{contract: @usdc_contract, chain_id: 1, type: :erc20, min_balance: 100, token_id: nil, role: nil}
      ]

      checker = fn _addr, _contract, _chain ->
        {:error, "RPC error"}
      end

      assert {:error, _} = TokenGate.check_access(@test_address, rules, checker)
    end

    test "passes with empty rules list" do
      checker = fn _, _, _ -> {:ok, 0} end
      assert {:ok, result} = TokenGate.check_access(@test_address, [], checker)
      assert result.passed == true
      assert result.roles == []
    end

    test "includes balance details in results" do
      rules = [
        %{contract: @usdc_contract, chain_id: 1, type: :erc20, min_balance: 100, token_id: nil, role: :holder}
      ]

      checker = fn _, _, _ -> {:ok, 500} end

      assert {:ok, result} = TokenGate.check_access(@test_address, rules, checker)
      [detail | _] = result.results
      assert detail.balance == 500
      assert detail.required == 100
      assert detail.passed == true
      assert detail.contract == @usdc_contract
    end
  end

  describe "check_access_any/3 (OR logic)" do
    test "passes when at least one rule is met" do
      rules = [
        %{contract: @usdc_contract, chain_id: 1, type: :erc20, min_balance: 1000, token_id: nil, role: :usdc_whale},
        %{contract: @nft_contract, chain_id: 1, type: :erc721, min_balance: 1, token_id: nil, role: :nft_holder}
      ]

      checker = fn _addr, contract, _chain ->
        case contract do
          @usdc_contract -> {:ok, 50}  # Below minimum
          @nft_contract -> {:ok, 1}    # Meets minimum
        end
      end

      assert {:ok, result} = TokenGate.check_access_any(@test_address, rules, checker)
      assert result.passed == true
      assert :nft_holder in result.roles
    end

    test "fails when no rules are met" do
      rules = [
        %{contract: @usdc_contract, chain_id: 1, type: :erc20, min_balance: 1000, token_id: nil, role: :usdc_whale},
        %{contract: @nft_contract, chain_id: 1, type: :erc721, min_balance: 5, token_id: nil, role: :nft_whale}
      ]

      checker = fn _, _, _ -> {:ok, 0} end

      assert {:ok, result} = TokenGate.check_access_any(@test_address, rules, checker)
      assert result.passed == false
      assert result.roles == []
    end
  end
end
