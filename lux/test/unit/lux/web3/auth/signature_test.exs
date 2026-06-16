defmodule Lux.Web3.Auth.SignatureTest do
  use UnitCase, async: true

  alias Lux.Web3.Auth.Signature

  @private_key <<120, 128, 174, 201, 52, 19, 241, 23, 239, 20, 189, 78, 109, 19, 8, 117,
                 171, 44, 125, 125, 85, 160, 100, 250, 195, 194, 247, 189, 81, 81, 99, 128>>

  @message """
  app.example.com wants you to sign in with your Ethereum account:
  0x0000000000000000000000000000000000000000

  URI: https://app.example.com/login
  Version: 1
  Chain ID: 1
  Nonce: n-123456
  Issued At: 2026-06-15T10:00:00Z
  """

  test "signs and recovers an Ethereum personal-sign address" do
    assert {:ok, signature} = Signature.sign_for_tests(@message, @private_key)
    assert {:ok, address} = Signature.recover_address(@message, signature)
    assert {:ok, ^address} = Signature.verify(@message, signature, address)
  end

  test "rejects signer mismatch" do
    assert {:ok, signature} = Signature.sign_for_tests(@message, @private_key)

    assert {:error, "SIWE signature signer does not match message address"} =
             Signature.verify(@message, signature, "0x0000000000000000000000000000000000000001")
  end

  test "rejects malformed signatures" do
    assert {:error, "SIWE signature must be hex encoded"} = Signature.recover_address(@message, "not-hex")
  end
end
