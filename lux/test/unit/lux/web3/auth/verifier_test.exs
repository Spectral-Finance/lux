defmodule Lux.Web3.Auth.Verifier.Test do
  use ExUnit.Case, async: true
  @moduletag :unit

  alias Lux.Web3.Auth.{SIWE, Verifier}

  describe "verify_siwe/2" do
    test "rejects an expired SIWE message" do
      siwe = %SIWE{
        domain: "expired.example.com",
        address: "0x1234567890abcdef1234567890abcdef12345678",
        uri: "https://expired.example.com",
        version: "1",
        chain_id: 1,
        nonce: "expired_nonce",
        issued_at: "2020-01-01T00:00:00Z",
        expiration_time: "2020-01-01T12:00:00Z"
      }

      assert {:error, "SIWE message has expired"} = Verifier.verify_siwe(siwe, "0xdeadbeef")
    end

    test "rejects an invalid SIWE message" do
      siwe = %SIWE{
        domain: "",
        address: "invalid",
        uri: "",
        version: "1",
        chain_id: 1,
        nonce: "",
        issued_at: ""
      }

      assert {:error, _} = Verifier.verify_siwe(siwe, "0xdeadbeef")
    end
  end

  describe "decode_signature" do
    test "handles invalid hex" do
      msg = "test message"
      result = Verifier.recover_address(msg, "zzzzzzz")
      assert {:error, _} = result
    end

    test "handles wrong-length signature" do
      msg = "test message"
      result = Verifier.recover_address(msg, "0x1234")
      assert {:error, _} = result
    end
  end

  describe "verify_personal_sign/2" do
    test "handles empty signature gracefully" do
      assert {:error, _} = Verifier.verify_personal_sign("hello", "")
    end
  end

  describe "verify/3" do
    test "returns error when signature does not match address" do
      assert {:error, _} =
        Verifier.verify("0x1234567890abcdef1234567890abcdef12345678", "message", "0xinvalid")
    end
  end
end
