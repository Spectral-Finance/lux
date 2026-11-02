defmodule Lux.Web3.Auth.SessionManagerTest do
  use ExUnit.Case, async: false

  alias Lux.Web3.Auth.SessionManager

  @test_address "0x95222290dd7278aa3ddd389cc1e1d165cc4bafe5"

  setup do
    server_name = :"session_mgr_test_#{:erlang.unique_integer()}"
    {:ok, pid} = SessionManager.start_link(name: server_name)
    %{server: server_name, pid: pid}
  end

  describe "create_session/3 and validate_session/3" do
    test "creates a signed bearer token and validates it", %{server: srv} do
      assert {:ok, %{token: token, session: session}} =
               SessionManager.create_session(@test_address, [roles: [:trader], chain_id: 1], srv)

      assert is_binary(token)
      assert session.address == @test_address
      assert session.roles == [:trader]

      assert {:ok, validated} = SessionManager.validate_session(token, [], srv)
      assert validated.session_id == session.session_id
      assert validated.address == @test_address
      assert validated.roles == [:trader]
    end

    test "handles expired sessions", %{server: srv} do
      now = ~U[2026-11-02 12:00:00Z]
      later = ~U[2026-11-02 12:05:00Z]

      {:ok, %{token: token}} =
        SessionManager.create_session(@test_address, [ttl: 60, as_of: now], srv)

      assert {:error, :session_expired} =
               SessionManager.validate_session(token, [as_of: later], srv)
    end
  end

  describe "revoke_session/2 and revoke_all_for_address/2" do
    test "revokes an individual session", %{server: srv} do
      {:ok, %{token: token, session: session}} =
        SessionManager.create_session(@test_address, [], srv)

      assert :ok = SessionManager.revoke_session(session.session_id, srv)
      assert {:error, :session_revoked} = SessionManager.validate_session(token, [], srv)
    end

    test "revokes all sessions for address", %{server: srv} do
      {:ok, %{token: token1}} = SessionManager.create_session(@test_address, [], srv)
      {:ok, %{token: token2}} = SessionManager.create_session(@test_address, [], srv)

      assert :ok = SessionManager.revoke_all_for_address(@test_address, srv)

      assert {:error, :session_revoked} = SessionManager.validate_session(token1, [], srv)
      assert {:error, :session_revoked} = SessionManager.validate_session(token2, [], srv)
    end
  end

  describe "list_active_sessions/2" do
    test "lists active sessions for an address", %{server: srv} do
      {:ok, _} = SessionManager.create_session(@test_address, [], srv)
      {:ok, _} = SessionManager.create_session(@test_address, [], srv)

      active = SessionManager.list_active_sessions(@test_address, srv)
      assert length(active) == 2
    end
  end
end
