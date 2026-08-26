defmodule LuxAppWeb.AuthControllerTest do
  use LuxAppWeb.ConnCase

  alias LuxAppWeb.Auth.{SessionManager, Permissions, RPCVerifier, RPCTokenGater}

  setup do
    # Configure a valid deployer policy for testing
    Application.put_env(:lux_app, :token_gating_policy, %{
      chain_id: "1",
      token_contract: "0x1111111111111111111111111111111111111111",
      min_balance: 1
    })

    Application.put_env(:lux_app, :chain_rpcs, %{
      "1" => "http://127.0.0.1:8545"
    })

    on_exit(fn ->
      Application.delete_env(:lux_app, :token_gating_policy)
      Application.delete_env(:lux_app, :chain_rpcs)
    end)

    :ok
  end

  describe "GET /api/auth/nonce" do
    test "returns a 32-character hex nonce and sets it in session", %{conn: conn} do
      conn = get(conn, "/api/auth/nonce")
      
      assert %{"nonce" => nonce} = json_response(conn, 200)
      assert String.length(nonce) == 32
      assert get_session(conn, :siwe_nonce) == nonce
    end
  end

  describe "POST /api/auth/verify" do
    setup %{conn: conn} do
      conn = 
        conn
        |> init_test_session(siwe_nonce: "testingnonce1234567890abcdef123456")
        |> Map.put(:host, "www.example.com")
        |> Map.put(:scheme, :http)
        |> Map.put(:port, 80)
      
      %{conn: conn}
    end

    test "fails if missing message or signature", %{conn: conn} do
      conn = post(conn, "/api/auth/verify", %{"message" => "msg"})
      assert %{"error" => "Missing message or signature parameter."} = json_response(conn, 400)
    end

    test "fails with invalid format SIWE message", %{conn: conn} do
      conn = post(conn, "/api/auth/verify", %{"message" => "invalid", "signature" => "0x00"})
      assert %{"error" => "Verification failed", "reason" => "invalid_siwe_message"} = json_response(conn, 401)
    end
    
    test "succeeds with known-valid EIP-4361 deterministic vector", %{conn: conn} do
      valid_message = """
      www.example.com wants you to sign in with your Ethereum account:
      0x97607faAE78d2D3E549B27d90f99F0e9A3BE1B58

      Login to Lux

      URI: http://www.example.com
      Version: 1
      Chain ID: 1
      Nonce: testingnonce1234567890abcdef123456
      Issued At: 2026-07-12T00:00:00Z
      Expiration Time: 2099-12-31T23:59:59Z
      """
      valid_message = String.trim(valid_message)
      valid_signature = "0x2aaedb0b0c2e52e65d2fcaa0c51e51884f3e73b8c87cf41a007f52f2dd9d9e2d12ef40c065e8ae8763ee46c1f10f1b7d57f4926e70e2305df50f41d8a7a2b8b01b"

      conn = post(conn, "/api/auth/verify", %{"message" => valid_message, "signature" => valid_signature})
      assert %{"success" => true, "address" => "0x97607faae78d2d3e549b27d90f99f0e9a3be1b58"} = json_response(conn, 200)
    end

    test "fails with expired message", %{conn: conn} do
      expired_message = """
      www.example.com wants you to sign in with your Ethereum account:
      0x97607faAE78d2D3E549B27d90f99F0e9A3BE1B58

      URI: http://www.example.com
      Version: 1
      Chain ID: 1
      Nonce: testingnonce1234567890abcdef123456
      Issued At: 2021-07-12T00:00:00Z
      Expiration Time: 2021-07-13T00:00:00Z
      """
      expired_message = String.trim(expired_message)
      
      conn = post(conn, "/api/auth/verify", %{"message" => expired_message, "signature" => "0x00"})
      assert %{"error" => "Verification failed", "reason" => "expired_message"} = json_response(conn, 401)
    end

    test "fails with not_before (nbf) in the future", %{conn: conn} do
      nbf_message = """
      www.example.com wants you to sign in with your Ethereum account:
      0x97607faAE78d2D3E549B27d90f99F0e9A3BE1B58

      URI: http://www.example.com
      Version: 1
      Chain ID: 1
      Nonce: testingnonce1234567890abcdef123456
      Issued At: 2026-07-12T00:00:00Z
      Expiration Time: 2099-12-31T23:59:59Z
      Not Before: 2099-01-01T00:00:00Z
      """
      nbf_message = String.trim(nbf_message)

      conn = post(conn, "/api/auth/verify", %{"message" => nbf_message, "signature" => "0x00"})
      assert %{"error" => "Verification failed", "reason" => "message_not_yet_valid"} = json_response(conn, 401)
    end

    test "fails with issued_at in the future", %{conn: conn} do
      future_iat_message = """
      www.example.com wants you to sign in with your Ethereum account:
      0x97607faAE78d2D3E549B27d90f99F0e9A3BE1B58

      URI: http://www.example.com
      Version: 1
      Chain ID: 1
      Nonce: testingnonce1234567890abcdef123456
      Issued At: 2099-12-31T23:59:59Z
      Expiration Time: 2099-12-31T23:59:59Z
      """
      future_iat_message = String.trim(future_iat_message)

      conn = post(conn, "/api/auth/verify", %{"message" => future_iat_message, "signature" => "0x00"})
      assert %{"error" => "Verification failed", "reason" => "issued_at_in_future"} = json_response(conn, 401)
    end

    test "succeeds via multisig EIP-1271 fallback bound to chain_id", %{conn: conn} do
      multisig_message = """
      www.example.com wants you to sign in with your Ethereum account:
      0x7777777777777777777777777777777777777777

      URI: http://www.example.com
      Version: 1
      Chain ID: 1
      Nonce: testingnonce1234567890abcdef123456
      Issued At: 2026-07-12T00:00:00Z
      Expiration Time: 2099-12-31T23:59:59Z
      """
      multisig_message = String.trim(multisig_message)
      valid_mock_signature = "0xvalid_eip1271_mock_signature_that_simulates_contract_response"

      conn = post(conn, "/api/auth/verify", %{"message" => multisig_message, "signature" => valid_mock_signature})
      assert %{"success" => true, "address" => "0x7777777777777777777777777777777777777777"} = json_response(conn, 200)
    end
  end

  describe "Router-level RBAC Enforcement on /api/admin/dashboard" do
    test "denies access to authenticated user with insufficient role", %{conn: conn} do
      conn = 
        conn
        |> init_test_session(web3_address: "0x123", role: "user", expires_at: System.system_time(:second) + 3600)
        |> get("/api/admin/dashboard")

      assert %{"error" => "Forbidden: Insufficient role"} = json_response(conn, 403)
    end

    test "grants access to authenticated user with admin role", %{conn: conn} do
      conn = 
        conn
        |> init_test_session(web3_address: "0x123", role: "admin", expires_at: System.system_time(:second) + 3600)
        |> get("/api/admin/dashboard")

      assert %{"status" => "ok", "message" => "Welcome Admin"} = json_response(conn, 200)
    end
  end

  describe "Token Gating via ProfileController on /api/secure/profile with session_chain_id" do
    test "denies access to normal wallet on matching chain", %{conn: conn} do
      conn = 
        conn
        |> init_test_session(web3_address: "0x1111111111111111111111111111111111111111", chain_id: "1", expires_at: System.system_time(:second) + 3600)
        |> get("/api/secure/profile")
        
      assert %{"error" => "Insufficient token balance for premium access."} = json_response(conn, 403)
    end

    test "allows access to VIP wallet on matching chain", %{conn: conn} do
      conn = 
        conn
        |> init_test_session(web3_address: "0x9999999999999999999999999999999999999999", chain_id: "1", expires_at: System.system_time(:second) + 3600)
        |> get("/api/secure/profile")
        
      assert %{"premium_access" => true} = json_response(conn, 200)
    end

    test "rejects valid holder authenticated on wrong session chain_id", %{conn: conn} do
      # VIP address authenticated on Polygon (chain_id 137), but policy requires chain_id 1
      conn = 
        conn
        |> init_test_session(web3_address: "0x9999999999999999999999999999999999999999", chain_id: "137", expires_at: System.system_time(:second) + 3600)
        |> get("/api/secure/profile")

      assert %{"error" => "Session chain ID mismatch with token gating policy."} = json_response(conn, 403)
    end

    test "defaults closed (403) when deployer policy is unconfigured or zero-address", %{conn: conn} do
      Application.delete_env(:lux_app, :token_gating_policy)

      conn = 
        conn
        |> init_test_session(web3_address: "0x9999999999999999999999999999999999999999", chain_id: "1", expires_at: System.system_time(:second) + 3600)
        |> get("/api/secure/profile")

      assert %{"error" => "Token gating policy unconfigured or invalid."} = json_response(conn, 403)
    end
  end

  describe "POST /api/auth/logout" do
    test "clears session", %{conn: conn} do
      conn = 
        conn
        |> init_test_session(web3_address: "0x123", role: "user")
        
      assert get_session(conn, :web3_address) == "0x123"
      
      conn = post(conn, "/api/auth/logout")
      assert %{"success" => true} = json_response(conn, 200)
      
      assert get_session(conn, :web3_address) == nil
    end
  end

  describe "Production RPC Adapters without Cross-Chain Fallback (Default Closed)" do
    test "RPCVerifier returns false for unconfigured chain_id (no global fallback)" do
      # Chain 99999 is not in :chain_rpcs
      assert RPCVerifier.get_rpc_url_for_chain("99999") == nil
      assert RPCVerifier.is_valid_signature?("msg", "0x00", "0x1111111111111111111111111111111111111111", "99999") == false
    end

    test "RPCTokenGater returns false for unconfigured chain_id or zero address" do
      assert RPCTokenGater.has_access?("0x123", "99999", "0x1111111111111111111111111111111111111111", 1) == false
      assert RPCTokenGater.has_access?("0x123", "1", "0x0000000000000000000000000000000000000000", 1) == false
    end
  end
end
