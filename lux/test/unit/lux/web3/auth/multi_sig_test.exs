defmodule Lux.Web3.Auth.MultiSigTest do
  use UnitCase, async: true

  alias Lux.Web3.Auth.{MultiSig, Signature}

  @key1 <<1::256>>
  @key2 <<2::256>>
  @key3 <<3::256>>

  test "accepts threshold of unique owner signatures" do
    message = "authorize treasury action"
    owners = [address(@key1), address(@key2), address(@key3)]
    signatures = [sign(message, @key1), sign(message, @key2), sign(message, @key2)]

    assert {:ok, %{valid_count: 2, valid_signers: signers}} =
             MultiSig.verify_threshold(message, signatures, owners, 2)

    assert Enum.sort(signers) ==
             Enum.sort([String.downcase(address(@key1)), String.downcase(address(@key2))])
  end

  test "rejects when threshold is not met" do
    message = "authorize treasury action"

    assert {:error, {:threshold_not_met, 1}} =
             MultiSig.verify_threshold(
               message,
               [sign(message, @key1)],
               [address(@key1), address(@key2)],
               2
             )
  end

  defp address(private_key) do
    {:ok, public_key} = ExSecp256k1.create_public_key(private_key)
    Ethers.Utils.public_key_to_address(public_key)
  end

  defp sign(message, private_key) do
    {:ok, {signature, recovery_id}} =
      ExSecp256k1.sign_compact(Signature.personal_hash(message), private_key)

    "0x" <> Base.encode16(signature <> <<recovery_id + 27>>, case: :lower)
  end
end
