defmodule Lux.Prisms.Web3.Auth.VerifySignaturePrismTest do
  @moduledoc """
  Tests for the VerifySignaturePrism module.
  """

  use UnitCase, async: true

  alias Lux.Prisms.Web3.Auth.VerifySignaturePrism

  @test_private_key Base.decode16!(
                      "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
                      case: :lower
                    )
  @test_address "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"

  defp sign_message(message) do
    hash = Lux.Web3.Auth.SignatureVerifier.hash_personal_message(message)
    {:ok, {signature, recovery_id}} = ExSecp256k1.sign_compact(hash, @test_private_key)
    "0x" <> Base.encode16(signature <> <<recovery_id + 27>>, case: :lower)
  end

  describe "handler/2" do
    test "verifies a valid personal_sign signature" do
      message = "Hello, world!"
      signature = sign_message(message)

      assert {:ok, result} =
               VerifySignaturePrism.handler(
                 %{
                   message: message,
                   signature: signature,
                   address: @test_address
                 },
                 %{}
               )

      assert result.valid == true
      assert String.downcase(result.recovered_address) == @test_address
    end

    test "detects invalid signature for address" do
      message = "Hello, world!"
      signature = sign_message(message)

      assert {:ok, result} =
               VerifySignaturePrism.handler(
                 %{
                   message: message,
                   signature: signature,
                   address: "0x0000000000000000000000000000000000000001"
                 },
                 %{}
               )

      assert result.valid == false
    end

    test "handles invalid signature format" do
      assert {:ok, result} =
               VerifySignaturePrism.handler(
                 %{
                   message: "test",
                   signature: "invalid",
                   address: @test_address
                 },
                 %{}
               )

      assert result.valid == false
    end

    test "handles missing parameters" do
      assert {:error, _} = VerifySignaturePrism.handler(%{}, %{})
    end

    test "returns the prism view" do
      view = VerifySignaturePrism.view()
      assert view.name == "Verify Ethereum Signature"
      assert view.input_schema != nil
    end
  end
end
