defmodule Lux.Prisms.Web3.AuthenticateSessionTest do
  use UnitCase, async: true

  alias Lux.Prisms.Web3.AuthenticateSession
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
  Expiration Time: 2099-06-15T10:00:00Z
  """

  test "creates an authenticated session from a signed SIWE message" do
    assert {:ok, bootstrap_signature} = Signature.sign_for_tests(@message, @private_key)
    assert {:ok, signer} = Signature.recover_address(@message, bootstrap_signature)
    message = String.replace(@message, "0x0000000000000000000000000000000000000000", signer)
    assert {:ok, signature} = Signature.sign_for_tests(message, @private_key)

    assert {:ok, result} =
             AuthenticateSession.handler(
               %{
                 message: message,
                 signature: signature,
                 domain: "app.example.com",
                 uri: "https://app.example.com/login",
                 nonce: "n-123456",
                 chain_ids: [1],
                 permissions: ["orders:read"],
                 roles: ["trader"]
               },
               nil
             )

    assert result.authenticated
    assert result.session.address == signer
    assert result.session.permissions == ["orders:read"]
    assert result.audit_event.result == "success"
  end
end
