defmodule Lux.Web3.Auth.SIWETest do
  use UnitCase, async: true

  alias Lux.Web3.Auth.{SIWE, Signature}

  @private_key <<1::256>>
  @address "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf"
  @issued_at "2026-05-13T09:00:00Z"
  @now ~U[2026-05-13 09:05:00Z]

  test "builds, parses, and validates EIP-4361 messages" do
    message = siwe_message()

    assert {:ok, parsed} = SIWE.parse_message(message)
    assert parsed.domain == "app.lux.dev"
    assert parsed.address == @address
    assert parsed.chain_id == 1
    assert parsed.resources == ["urn:lux:workspace:alpha"]

    assert :ok =
             SIWE.validate_message(parsed,
               domain: "app.lux.dev",
               chain_id: 1,
               nonce: "abc12345",
               now: @now
             )
  end

  test "authenticates a SIWE signature" do
    message = siwe_message()
    signature = sign(message, @private_key)

    assert {:ok, %{address: @address}} =
             SIWE.authenticate(message, signature, domain: "app.lux.dev", chain_id: 1, now: @now)
  end

  test "rejects expired or mismatched messages" do
    message = siwe_message(expiration_time: "2026-05-13T09:01:00Z")
    {:ok, parsed} = SIWE.parse_message(message)

    assert {:error, :expired} = SIWE.validate_message(parsed, now: @now)

    assert {:error, :domain_mismatch} =
             SIWE.validate_message(%{parsed | expiration_time: nil}, domain: "evil.test")
  end

  test "parses messages without a statement" do
    message =
      SIWE.build_message(%{
        domain: "app.lux.dev",
        address: @address,
        uri: "https://app.lux.dev",
        chain_id: 1,
        nonce: "abc12345",
        issued_at: @issued_at
      })

    assert {:ok, parsed} = SIWE.parse_message(message)
    refute Map.has_key?(parsed, :statement)
  end

  defp siwe_message(extra \\ []) do
    attrs =
      %{
        domain: "app.lux.dev",
        address: @address,
        statement: "Authorize Lux workspace access",
        uri: "https://app.lux.dev",
        chain_id: 1,
        nonce: "abc12345",
        issued_at: @issued_at,
        resources: ["urn:lux:workspace:alpha"]
      }
      |> Map.merge(Map.new(extra))

    SIWE.build_message(attrs)
  end

  defp sign(message, private_key) do
    {:ok, {signature, recovery_id}} =
      ExSecp256k1.sign_compact(Signature.personal_hash(message), private_key)

    "0x" <> Base.encode16(signature <> <<recovery_id + 27>>, case: :lower)
  end
end
