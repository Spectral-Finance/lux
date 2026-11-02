defmodule Lux.Web3.WalletInfrastructure.TransactionBuilderTest do
  use UnitCase, async: true

  alias Lux.Web3.WalletInfrastructure.TransactionBuilder

  describe "build_eip1559/1 and sign_transaction/2" do
    test "constructs and signs valid EIP-1559 transaction" do
      params = %{
        chain_id: 1,
        nonce: 5,
        to: "0xd8da6bf26964af9d7eed9e03e53415d37aa96045",
        value: "0xde0b6b3a7640000", # 1 ETH
        data: "0x",
        gas_limit: 21_000,
        max_fee_per_gas: 35_000_000_000,
        max_priority_fee_per_gas: 2_000_000_000
      }

      tx = TransactionBuilder.build_eip1559(params)

      assert tx.type == 2
      assert tx.chain_id == 1
      assert tx.nonce == 5
      assert tx.max_fee_per_gas == 35_000_000_000

      key = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
      signed = TransactionBuilder.sign_transaction(tx, key)

      assert String.starts_with?(signed.tx_hash, "0x")
      assert String.starts_with?(signed.r, "0x")
      assert String.starts_with?(signed.s, "0x")
      assert String.starts_with?(signed.serialized_hex, "0x02")
    end
  end

  describe "build_eip712_payload/5" do
    test "constructs EIP-712 typed structured data hash" do
      types = %{
        EIP712Domain: [%{name: "name", type: "string"}, %{name: "version", type: "string"}],
        Permit: [%{name: "owner", type: "address"}, %{name: "spender", type: "address"}]
      }
      message = %{owner: "0x1111", spender: "0x2222"}

      payload = TransactionBuilder.build_eip712_payload("USDC", 1, "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48", types, message)

      assert payload.primaryType == "Permit"
      assert is_binary(payload.signing_hash)
      assert String.starts_with?(payload.signing_hash, "0x")
    end
  end
end
