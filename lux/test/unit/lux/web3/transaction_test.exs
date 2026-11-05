defmodule Lux.Web3.TransactionTest do
  use UnitCase, async: true

  alias Lux.Web3.Transaction

  doctest Lux.Web3.Transaction

  @to "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"

  describe "build/1 (happy path)" do
    test "builds a validated EIP-1559 transaction from required fields" do
      assert {:ok, tx} = Transaction.build(%{chain_id: 1, nonce: 0, to: @to})

      assert tx.chain_id == 1
      assert tx.nonce == 0
      assert tx.to == @to
      assert tx.value == 0
      assert tx.gas == 21_000
      assert tx.max_priority_fee_per_gas == 1_500_000_000
      assert tx.max_fee_per_gas == 1_500_000_000
    end

    test "accepts a numeric string chain id" do
      assert {:ok, %{chain_id: 1}} = Transaction.build(%{chain_id: "1", nonce: 0, to: @to})
    end

    test "honours an explicit value, gas and access list" do
      assert {:ok, tx} =
               Transaction.build(%{
                 chain_id: 137,
                 nonce: 4,
                 to: @to,
                 value: 1_000_000_000_000_000_000,
                 gas: 30_000,
                 access_list: []
               })

      assert tx.value == 1_000_000_000_000_000_000
      assert tx.gas == 30_000
    end
  end

  describe "build/1 (null and empty input)" do
    test "null and non-map input are rejected" do
      assert {:error, :invalid_transaction} = Transaction.build(nil)
      assert {:error, :invalid_transaction} = Transaction.build("transaction")
      assert {:error, :invalid_transaction} = Transaction.build([])
    end

    test "missing required fields map to typed errors" do
      assert {:error, :missing_chain_id} = Transaction.build(%{nonce: 0, to: @to})
      assert {:error, :missing_nonce} = Transaction.build(%{chain_id: 1, to: @to})
      assert {:error, :missing_to} = Transaction.build(%{chain_id: 1, nonce: 0})
    end

    test "an empty recipient is rejected as an invalid address" do
      assert {:error, :invalid_address} = Transaction.build(%{chain_id: 1, nonce: 0, to: ""})
      assert {:error, :invalid_address} = Transaction.build(%{chain_id: 1, nonce: 0, to: "   "})
    end

    test "an empty input is treated as a plain transfer" do
      assert {:ok, %{gas: 21_000}} =
               Transaction.build(%{chain_id: 1, nonce: 0, to: @to, input: ""})
    end
  end

  describe "build/1 (boundaries)" do
    test "accepts the zero lower bounds" do
      assert {:ok, %{value: 0, nonce: 0, gas: 0}} =
               Transaction.build(%{chain_id: 1, nonce: 0, to: @to, value: 0, gas: 0})
    end

    test "accepts a large upper bound value" do
      huge = Integer.pow(2, 200)

      assert {:ok, %{value: ^huge}} =
               Transaction.build(%{chain_id: 1, nonce: 0, to: @to, value: huge})
    end

    test "allows max_fee_per_gas to equal the priority fee" do
      assert {:ok, %{max_fee_per_gas: 2_000_000_000, max_priority_fee_per_gas: 2_000_000_000}} =
               Transaction.build(%{
                 chain_id: 1,
                 nonce: 0,
                 to: @to,
                 max_fee_per_gas: 2_000_000_000,
                 max_priority_fee_per_gas: 2_000_000_000
               })
    end

    test "allows max_fee_per_gas to equal the base fee" do
      assert {:ok, %{max_fee_per_gas: 100, max_priority_fee_per_gas: 100}} =
               Transaction.build(%{
                 chain_id: 1,
                 nonce: 0,
                 to: @to,
                 base_fee_per_gas: 100,
                 max_fee_per_gas: 100,
                 max_priority_fee_per_gas: 100
               })
    end
  end

  describe "build/1 (negative cases)" do
    test "rejects negative value, nonce and gas" do
      assert {:error, :invalid_amount} =
               Transaction.build(%{chain_id: 1, nonce: 0, to: @to, value: -1})

      assert {:error, :invalid_nonce} =
               Transaction.build(%{chain_id: 1, nonce: -1, to: @to})

      assert {:error, :invalid_gas} =
               Transaction.build(%{chain_id: 1, nonce: 0, to: @to, gas: -1})
    end

    test "rejects a malformed recipient and non-binary input" do
      assert {:error, :invalid_address} =
               Transaction.build(%{chain_id: 1, nonce: 0, to: "not-an-address"})

      assert {:error, :invalid_input} =
               Transaction.build(%{chain_id: 1, nonce: 0, to: @to, input: 123})
    end

    test "rejects an unsupported chain" do
      assert {:error, :unsupported_chain} =
               Transaction.build(%{chain_id: 424_242, nonce: 0, to: @to})
    end

    test "rejects an inconsistent fee pair" do
      assert {:error, :fee_too_low} =
               Transaction.build(%{
                 chain_id: 1,
                 nonce: 0,
                 to: @to,
                 max_fee_per_gas: 1,
                 max_priority_fee_per_gas: 2
               })
    end

    test "rejects a max fee below the base fee" do
      assert {:error, :max_fee_below_base_fee} =
               Transaction.build(%{
                 chain_id: 1,
                 nonce: 0,
                 to: @to,
                 base_fee_per_gas: 2_000_000_000,
                 max_fee_per_gas: 1_600_000_000,
                 max_priority_fee_per_gas: 1_500_000_000
               })
    end
  end

  describe "estimate_gas/1" do
    test "plain transfers use the intrinsic gas" do
      assert Transaction.estimate_gas(%{}) == 21_000
      assert Transaction.estimate_gas(%{input: ""}) == 21_000
      assert Transaction.estimate_gas(%{data: ""}) == 21_000
    end

    test "contract payloads add a per-byte cost" do
      # one zero byte (4 gas) and two non-zero bytes (16 gas each)
      assert Transaction.estimate_gas(%{input: <<0, 1, 2>>}) == 50_000 + 4 + 16 + 16
    end

    test "non-map input falls back to the intrinsic gas" do
      assert Transaction.estimate_gas(nil) == 21_000
      assert Transaction.estimate_gas("payload") == 21_000
    end
  end

  describe "estimate_fees/2" do
    test "defaults the priority fee and doubles the base fee" do
      assert {:ok, fees} = Transaction.estimate_fees(2_000)
      assert fees.max_priority_fee_per_gas == 1_500_000_000
      assert fees.max_fee_per_gas == 2_000 * 2 + 1_500_000_000
    end

    test "honours a custom priority fee and multiplier" do
      assert {:ok, fees} = Transaction.estimate_fees(10, priority_fee_per_gas: 5, multiplier: 3)
      assert fees.max_priority_fee_per_gas == 5
      assert fees.max_fee_per_gas == 10 * 3 + 5
    end

    test "accepts a zero base fee at the lower boundary" do
      assert {:ok, %{max_priority_fee_per_gas: 1_500_000_000}} = Transaction.estimate_fees(0)
    end

    test "rejects negative and non-positive boundary inputs" do
      assert {:error, :invalid_base_fee} = Transaction.estimate_fees(-1)

      assert {:error, :invalid_priority_fee} =
               Transaction.estimate_fees(0, priority_fee_per_gas: -1)

      assert {:error, :invalid_multiplier} = Transaction.estimate_fees(0, multiplier: 0)
      assert {:error, :invalid_multiplier} = Transaction.estimate_fees(0, multiplier: -2)
    end
  end

  describe "total_fee/1" do
    test "is gas times the max fee per gas" do
      {:ok, tx} =
        Transaction.build(%{
          chain_id: 1,
          nonce: 0,
          to: @to,
          gas: 30_000,
          max_fee_per_gas: 2_000_000_000,
          max_priority_fee_per_gas: 1_000_000_000
        })

      assert Transaction.total_fee(tx) == 30_000 * 2_000_000_000
    end
  end

  describe "sign/2, hash/1 and decode/1" do
    setup do
      mnemonic =
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

      {:ok, wallet} = Lux.Web3.Wallet.HD.from_mnemonic(mnemonic)
      {:ok, tx} = Transaction.build(%{chain_id: 1, nonce: 0, to: @to, value: 1_000, gas: 30_000})

      {:ok, wallet: wallet, tx: tx}
    end

    test "signs into a raw hex transaction and hashes deterministically", %{
      wallet: wallet,
      tx: tx
    } do
      assert {:ok, "0x" <> _hex = raw} = Transaction.sign(tx, wallet)
      assert Transaction.hash(raw) == Transaction.hash(raw)
      assert String.starts_with?(Transaction.hash(raw), "0x")
    end

    test "decodes a signed transaction back to its payload", %{wallet: wallet, tx: tx} do
      {:ok, raw} = Transaction.sign(tx, wallet)

      assert {:ok, decoded} = Transaction.decode(raw)
      assert decoded.payload.chain_id == tx.chain_id
      assert decoded.payload.nonce == tx.nonce
      assert decoded.payload.to == tx.to
      assert decoded.payload.value == tx.value
      assert byte_size(decoded.signature_r) == 32
    end

    test "refuses to sign with a watch-only wallet", %{tx: tx} do
      {:ok, watch_only} = Lux.Web3.Wallet.import_address(@to, type: :hardware)

      assert {:error, :not_a_signing_wallet} = Transaction.sign(tx, watch_only)
    end
  end
end
