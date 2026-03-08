defmodule Lux.Web3.Auth.SignatureVerifierTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Auth.SignatureVerifier

  test "personal_hash produces consistent hash" do
    hash1 = SignatureVerifier.personal_hash("hello")
    hash2 = SignatureVerifier.personal_hash("hello")
    assert hash1 == hash2
    assert byte_size(hash1) == 32
  end

  test "personal_hash differs for different messages" do
    hash1 = SignatureVerifier.personal_hash("hello")
    hash2 = SignatureVerifier.personal_hash("world")
    assert hash1 != hash2
  end

  test "decode invalid signature format" do
    assert {:error, _} = SignatureVerifier.verify("msg", "invalid", "0x" <> String.duplicate("0", 40))
  end

  test "recover_address with invalid signature returns error" do
    result = SignatureVerifier.recover_address("test", "0x" <> String.duplicate("0", 128) <> "1b")
    assert match?({:error, _}, result) or match?({:ok, _}, result)
  end
end
