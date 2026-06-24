defmodule LuxApp.Contexts.Web3AuthTest do
  use ExUnit.Case, async: false
  alias LuxApp.Contexts.Web3Auth

  describe "normalize_address/1" do
    test "normalizes lowercase address" do
      assert Web3Auth.normalize_address("0xab16ca55b14eb61ccdc08ecda89486338297f5bb") ==
               "0xab16ca55b14eb61ccdc08ecda89486338297f5bb"
    end

    test "normalizes uppercase address" do
      assert Web3Auth.normalize_address("0xAB16CA55B14EB61CCDC08ECDA89486338297F5BB") ==
               "0xab16ca55b14eb61ccdc08ecda89486338297f5bb"
    end

    test "normalizes mixed case address" do
      assert Web3Auth.normalize_address("0xAb16ca55B14eB61cCdC08eCdA89486338297f5Bb") ==
               "0xab16ca55b14eb61ccdc08ecda89486338297f5bb"
    end

    test "adds 0x prefix if missing" do
      assert Web3Auth.normalize_address("ab16ca55b14eb61ccdc08ecda89486338297f5bb") ==
               "0xab16ca55b14eb61ccdc08ecda89486338297f5bb"
    end
  end

  describe "generate_nonce/0" do
    test "generates a 64-character hex string" do
      nonce = Web3Auth.generate_nonce()
      assert String.length(nonce) == 64
      assert Regex.match?(~r/^[0-9a-f]+$/, nonce)
    end

    test "generates unique nonces" do
      nonce1 = Web3Auth.generate_nonce()
      nonce2 = Web3Auth.generate_nonce()
      assert nonce1 != nonce2
    end
  end

  describe "format_siwe_message/1" do
    test "formats a valid SIWE message" do
      session = %LuxApp.Schemas.Web3AuthSession{
        id: "test-id",
        wallet_address: "0xab16ca55b14eb61ccdc08ecda89486338297f5bb",
        chain_id: 1,
        nonce: "test-nonce",
        domain: "lux.spectral.finance",
        statement: "Sign in to Lux",
        issued_at: DateTime.utc_now(),
        expires_at: DateTime.utc_now() |> DateTime.add(86400, :second),
        signature: "",
        roles: [],
        permissions: [],
        metadata: %{}
      }

      message = Web3Auth.format_siwe_message(session)

      assert String.contains?(message, "lux.spectral.finance wants you to sign in")
      assert String.contains?(message, "0xab16ca55b14eb61ccdc08ecda89486338297f5bb")
      assert String.contains?(message, "https://lux.spectral.finance")
      assert String.contains?(message, "Chain ID: 1")
      assert String.contains?(message, "nonce: test-nonce")
      assert String.contains?(message, "Sign in to Lux")
    end
  end

  describe "format_datetime/1" do
    test "formats datetime as ISO 8601" do
      dt = DateTime.utc_now()
      formatted = Web3Auth.format_datetime(dt)
      assert String.contains?(formatted, "T")
      assert String.contains?(formatted, ":")
    end
  end

  describe "valid_session?/1" do
    test "returns true for valid session" do
      session = %LuxApp.Schemas.Web3AuthSession{
        expires_at: DateTime.utc_now() |> DateTime.add(86400, :second),
        revoked_at: nil
      }
      assert Web3Auth.valid_session?(session) == true
    end

    test "returns false for expired session" do
      session = %LuxApp.Schemas.Web3AuthSession{
        expires_at: DateTime.utc_now() |> DateTime.add(-86400, :second),
        revoked_at: nil
      }
      assert Web3Auth.valid_session?(session) == false
    end

    test "returns false for revoked session" do
      session = %LuxApp.Schemas.Web3AuthSession{
        expires_at: DateTime.utc_now() |> DateTime.add(86400, :second),
        revoked_at: DateTime.utc_now()
      }
      assert Web3Auth.valid_session?(session) == false
    end
  end

  describe "has_permission?/3" do
    test "returns false when no permissions exist" do
      assert Web3Auth.has_permission?("0xab16ca55b14eb61ccdc08ecda89486338297f5bb", "agents", "create") ==
               false
    end
  end

  describe "has_role?/2" do
    test "returns false when no roles exist" do
      assert Web3Auth.has_role?("0xab16ca55b14eb61ccdc08ecda89486338297f5bb", "admin") == false
    end
  end

  describe "verify_token_gate/3" do
    test "returns error when condition is incomplete" do
      result = Web3Auth.verify_token_gate("0xab16ca55b14eb61ccdc08ecda89486338297f5bb", %{})
      assert result == {:error, "Missing contract_address or threshold in condition"}
    end

    test "returns ok in dry_run mode" do
      condition = %{
        chain_id: 1,
        contract_address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        threshold: 100,
        decimals: 6
      }
      assert Web3Auth.verify_token_gate("0xab16ca55b14eb61ccdc08ecda89486338297f5bb", condition, dry_run: true) ==
               {:ok, true}
    end
  end

  describe "check_token_gates/3" do
    test "returns ok when all conditions pass in dry_run" do
      conditions = [
        %{
          chain_id: 1,
          contract_address: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
          threshold: 100,
          decimals: 6
        }
      ]
      assert Web3Auth.check_token_gates("0xab16ca55b14eb61ccdc08ecda89486338297f5bb", conditions, dry_run: true) ==
               {:ok, true}
    end
  end

  describe "resolve_permissions/1" do
    test "returns empty list when no permissions exist" do
      assert Web3Auth.resolve_permissions([]) == []
    end
  end

  describe "resolve_roles/1" do
    test "returns empty list when no roles exist" do
      assert Web3Auth.resolve_roles("0xab16ca55b14eb61ccdc08ecda89486338297f5bb") == []
    end
  end
end
