defmodule Lux.Web3.Auth.SignatureTest do
  use UnitCase, async: true

  alias Lux.Web3.Auth.Signature

  @private_key <<1::256>>
  @address "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf"

  test "recovers and verifies personal-sign signatures" do
    message = "Sign in to Lux"
    signature = sign(message, @private_key)

    assert {:ok, @address} = Signature.recover_address(message, signature)

    assert :ok =
             Signature.verify_personal_signature(message, signature, String.downcase(@address))
  end

  test "rejects mismatched signatures" do
    signature = sign("first message", @private_key)

    assert {:error, :signature_mismatch} =
             Signature.verify_personal_signature(
               "first message",
               signature,
               "0x0000000000000000000000000000000000000001"
             )
  end

  test "validates address shape" do
    assert Signature.valid_address?(@address)
    refute Signature.valid_address?("0x123")
  end

  defp sign(message, private_key) do
    {:ok, {signature, recovery_id}} =
      ExSecp256k1.sign_compact(Signature.personal_hash(message), private_key)

    "0x" <> Base.encode16(signature <> <<recovery_id + 27>>, case: :lower)
  end
end
