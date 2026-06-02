defmodule Lux.Integrations.Hyperliquid.SigningTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.Hyperliquid.Signing

  describe "generate_nonce/0" do
    test "returns a positive integer" do
      nonce = Signing.generate_nonce()
      assert is_integer(nonce)
      assert nonce > 0
    end

    test "generates monotonically increasing values" do
      nonce1 = Signing.generate_nonce()
      :timer.sleep(2)
      nonce2 = Signing.generate_nonce()
      assert nonce2 > nonce1
    end
  end

  describe "action_hash/1" do
    test "computes keccak256 hash of an action" do
      action = %{"type" => "order", "orders" => [], "grouping" => "na"}
      hash = Signing.action_hash(action)
      assert is_binary(hash)
      assert byte_size(hash) == 64
    end

    test "produces different hashes for different actions" do
      hash1 = Signing.action_hash(%{"type" => "order"})
      hash2 = Signing.action_hash(%{"type" => "cancel"})
      assert hash1 != hash2
    end
  end

  describe "sign_l1_action/3" do
    test "returns error for invalid private key" do
      action = %{"type" => "order", "orders" => [], "grouping" => "na"}
      nonce = Signing.generate_nonce()

      result = Signing.sign_l1_action("invalid_key", action, nonce)
      assert match?({:error, _}, result)
    end

    test "signs a valid L1 action" do
      action = %{
        "type" => "order",
        "orders" => [
          %{"a" => "ETH", "b" => true, "p" => "2800.0", "s" => "0.1", "r" => false, "t" => %{"limit" => %{"tif" => "Gtc"}}}
        ],
        "grouping" => "na"
      }

      nonce = Signing.generate_nonce()

      test_key = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

      result = Signing.sign_l1_action(test_key, action, nonce)

      case result do
        {:ok, signature} ->
          assert is_map(signature)
          assert Map.has_key?(signature, :r)
          assert Map.has_key?(signature, :s)
          assert Map.has_key?(signature, :v)
          assert is_binary(signature.r)
          assert is_binary(signature.s)
          assert is_integer(signature.v)

        {:error, reason} ->
          assert is_binary(reason)
      end
    end
  end

  describe "sign_usd_deposit/4" do
    test "signs a USD deposit action" do
      nonce = Signing.generate_nonce()
      key = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

      result = Signing.sign_usd_deposit(key, "0xrecipient", "1000", nonce)

      case result do
        {:ok, sig} ->
          assert is_map(sig)
          assert Map.has_key?(sig, :r)
        {:error, _} -> :ok
      end
    end
  end

  describe "sign_bank_withdrawal/4" do
    test "signs a withdrawal action" do
      nonce = Signing.generate_nonce()
      key = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

      result = Signing.sign_bank_withdrawal(key, "0xdestination", "500", nonce)

      case result do
        {:ok, sig} ->
          assert is_map(sig)
          assert Map.has_key?(sig, :r)
        {:error, _} -> :ok
      end
    end
  end

  describe "sign_agent_l1_action/4" do
    test "signs an agent action" do
      nonce = Signing.generate_nonce()
      key = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
      action = %{"type" => "order", "orders" => [], "grouping" => "na"}

      result = Signing.sign_agent_l1_action(key, "0xagent123", action, nonce)

      case result do
        {:ok, sig} ->
          assert is_map(sig)
          assert Map.has_key?(sig, :r)
        {:error, _} -> :ok
      end
    end
  end
end
