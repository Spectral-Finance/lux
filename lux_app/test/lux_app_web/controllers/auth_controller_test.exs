defmodule LuxAppWeb.AuthControllerTest do
  use LuxAppWeb.ConnCase

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
      # Initialize session with a fixed nonce for testing
      conn = 
        conn
        |> init_test_session(siwe_nonce: "testingnonce1234567890abcdef123456")
      
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
    
    test "fails when nonce mismatch occurs", %{conn: conn} do
      # Nonce in message is different from the session one
      message = "example.com wants you to sign in with your Ethereum account:\n0x1234567890123456789012345678901234567890\n\nNonce: WRONGNONCE"
      conn = post(conn, "/api/auth/verify", %{"message" => message, "signature" => "0x00"})
      assert %{"error" => "Verification failed", "reason" => "nonce_mismatch"} = json_response(conn, 401)
    end

    # Note: Valid signature testing requires an actual secp256k1 valid (message, signature) pair.
    # The integration testing for full SIWE covers exact signature matching.
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
end
