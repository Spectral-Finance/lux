defmodule Lux.AuthTest do
  use ExUnit.Case, async: true

  alias Lux.Auth

  @test_secret "test_jwt_secret_key_12345"

  describe "generate_api_key/1" do
    test "generates a valid API key" do
      assert {:ok, key} = Auth.generate_api_key()
      assert String.starts_with?(key, "lux_ak_")
      assert byte_size(key) > 10
    end

    test "generates key with custom prefix" do
      assert {:ok, key} = Auth.generate_api_key(prefix: "test_")
      assert String.starts_with?(key, "test_")
    end

    test "generates unique keys" do
      {:ok, key1} = Auth.generate_api_key()
      {:ok, key2} = Auth.generate_api_key()
      assert key1 != key2
    end
  end

  describe "validate_api_key/2" do
    test "validates correct key format" do
      assert Auth.validate_api_key("lux_ak_abc123xyz") == true
    end

    test "rejects invalid prefix" do
      assert Auth.validate_api_key("invalid_key") == false
    end

    test "rejects too short key" do
      assert Auth.validate_api_key("lux_ak_ab") == false
    end

    test "accepts custom prefix" do
      assert Auth.validate_api_key("test_abc123", prefix: "test_") == true
    end
  end

  describe "hash_api_key/2 and verify_api_key/2" do
    test "hashes and verifies API key" do
      key = "lux_ak_test_key_123"
      hash = Auth.hash_api_key(key)

      assert String.starts_with?(hash, "sha256_")
      assert Auth.verify_api_key(key, hash) == true
    end

    test "fails verification with wrong key" do
      hash = Auth.hash_api_key("correct_key")
      assert Auth.verify_api_key("wrong_key", hash) == false
    end

    test "different salts produce different hashes" do
      key = "same_key"
      hash1 = Auth.hash_api_key(key, salt: "salt1")
      hash2 = Auth.hash_api_key(key, salt: "salt2")

      assert hash1 != hash2
    end
  end

  describe "generate_jwt/2 and verify_jwt/2" do
    setup do
      System.put_env("LUX_JWT_SECRET", @test_secret)
      :ok
    end

    test "generates and verifies JWT token" do
      claims = %{user_id: "123", role: "admin"}

      assert {:ok, token} = Auth.generate_jwt(claims, expires_in: 3600)
      assert is_binary(token)
      assert String.contains?(token, ".")

      assert {:ok, decoded} = Auth.verify_jwt(token, secret: @test_secret)
      assert decoded.user_id == "123"
      assert decoded.role == "admin"
    end

    test "JWT contains expiration" do
      assert {:ok, token} = Auth.generate_jwt(%{}, expires_in: 60)
      assert {:ok, claims} = Auth.verify_jwt(token, secret: @test_secret)
      assert Map.has_key?(claims, "exp")
      assert Map.has_key?(claims, "iat")
      assert Map.has_key?(claims, "iss")
    end

    test "rejects tampered token" do
      assert {:ok, token} = Auth.generate_jwt(%{user_id: "123"}, secret: @test_secret)
      tampered = String.replace(token, ".", "tampered.", 1)
      assert {:error, :invalid_signature} = Auth.verify_jwt(tampered, secret: @test_secret)
    end

    test "rejects malformed token" do
      assert {:error, :malformed_token} = Auth.verify_jwt("not.a.valid.jwt.token")
    end

    test "decode_jwt without verification" do
      assert {:ok, token} = Auth.generate_jwt(%{user_id: "test"}, secret: @test_secret)
      assert {:ok, claims} = Auth.decode_jwt(token)
      assert claims.user_id == "test"
    end
  end

  describe "sign_request/3 and verify_signature/3" do
    test "creates and verifies HMAC signature" do
      message = "GET /api/data"
      secret = "my_secret"

      signature = Auth.sign_request(message, secret)
      assert String.starts_with?(signature, "sha256_")
      assert Auth.verify_signature(message, signature, secret) == true
    end

    test "fails verification with wrong message" do
      signature = Auth.sign_request("original", "secret")
      assert Auth.verify_signature("modified", signature, "secret") == false
    end

    test "fails verification with wrong secret" do
      signature = Auth.sign_request("message", "secret1")
      assert Auth.verify_signature("message", signature, "secret2") == false
    end
  end

  describe "generate_secret/1" do
    test "generates hex-encoded secret" do
      assert {:ok, secret} = Auth.generate_secret()
      assert is_binary(secret)
      assert String.match?(secret, ~r/^[0-9a-f]+$/)
    end

    test "respects custom length" do
      assert {:ok, secret} = Auth.generate_secret(length: 64)
      assert byte_size(secret) == 64
    end
  end

  describe "encrypt/3 and decrypt/3" do
    test "encrypts and decrypts data" do
      {:ok, key} = Auth.generate_secret(length: 32)
      plaintext = "secret data that needs protection"

      assert {:ok, encrypted} = Auth.encrypt(plaintext, key)
      assert encrypted != plaintext
      assert is_binary(encrypted)

      assert {:ok, decrypted} = Auth.decrypt(encrypted, key)
      assert decrypted == plaintext
    end

    test "rejects invalid key length" do
      {:ok, plaintext} = Auth.generate_secret(length: 16) |> Auth.encrypt("data")

      assert {:error, :invalid_key_length} = Auth.encrypt("data", "short_key")
    end

    test "fails decryption with wrong key" do
      {:ok, key1} = Auth.generate_secret(length: 32)
      {:ok, key2} = Auth.generate_secret(length: 32)
      {:ok, encrypted} = Auth.encrypt("secret", key1)

      assert {:error, :decryption_failed} = Auth.decrypt(encrypted, key2)
    end

    test "supports additional authenticated data" do
      {:ok, key} = Auth.generate_secret(length: 32)
      plaintext = "sensitive data"
      aad = "context:payment"

      assert {:ok, encrypted} = Auth.encrypt(plaintext, key, aad: aad)
      assert {:ok, decrypted} = Auth.decrypt(encrypted, key, aad: aad)
      assert decrypted == plaintext

      # Wrong AAD should fail
      assert {:error, :decryption_failed} = Auth.decrypt(encrypted, key, aad: "wrong")
    end
  end

  describe "has_permission?/2" do
    test "admin has all permissions" do
      assert Auth.has_permission?("admin", "prisms.write") == true
      assert Auth.has_permission?("admin", "beams.run") == true
      assert Auth.has_permission?("admin", "config.write") == true
    end

    test "viewer can only read" do
      assert Auth.has_permission?("viewer", "prisms.read") == true
      assert Auth.has_permission?("viewer", "prisms.write") == false
      assert Auth.has_permission?("viewer", "config.write") == false
    end

    test "editor can write prisms" do
      assert Auth.has_permission?("editor", "prisms.write") == true
      assert Auth.has_permission?("editor", "prisms.read") == true
      assert Auth.has_permission?("editor", "users.manage") == false
    end

    test "service role has execute permissions" do
      assert Auth.has_permission?("service", "prisms.execute") == true
      assert Auth.has_permission?("service", "beams.run") == true
    end
  end

  describe "role_permissions/1" do
    test "returns permissions for admin role" do
      perms = Auth.role_permissions("admin")
      assert Enum.member?(perms, "*")
      assert length(perms) > 5
    end

    test "returns default permissions for unknown role" do
      perms = Auth.role_permissions("unknown_role")
      assert Enum.member?(perms, "prisms.read")
    end
  end

  describe "permission/2" do
    test "formats permission string" do
      assert Auth.permission("prisms", "read") == "prisms.read"
      assert Auth.permission("beams", "execute") == "beams.execute"
      assert Auth.permission("config", "write") == "config.write"
    end
  end

  describe "auth_status/1" do
    test "returns unauthorized when no token" do
      assert {:error, :no_token} = Auth.auth_status(%{})
    end

    test "returns authenticated status with valid token" do
      {:ok, token} = Auth.generate_jwt(%{user_id: "123", roles: ["admin"]}, secret: @test_secret)

      assert {:ok, status} = Auth.auth_status(%{token: token})
      assert status.authenticated == true
      assert status.user_id == "123"
      assert Enum.member?(status.roles, "admin")
    end

    test "returns error with invalid token" do
      assert {:error, :invalid_token} = Auth.auth_status(%{token: 123})
    end
  end
end
