defmodule Lux.Web3.SessionTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Session.Manager

  setup do
    # Ensure session manager is running
    {:ok, _pid} = Manager.start_link()
    :ok
  end

  describe "create_session/2" do
    test "creates a session with a unique ID" do
      {:ok, session_id} = Manager.create_session("0xabc123", %{ttl_seconds: 3600})

      assert is_binary(session_id)
      assert byte_size(session_id) > 0
    end

    test "stores session metadata" do
      {:ok, session_id} = Manager.create_session("0xdef456", %{ttl_seconds: 1800})

      assert {:ok, session} = Manager.get_session(session_id)
      assert session[:address] == "0xdef456"
      assert session[:valid] == true
      assert is_map_key(session, :created_at)
      assert is_map_key(session, :expires_at)
    end
  end

  describe "get_session/1" do
    test "returns error for non-existent session" do
      assert {:error, :not_found} = Manager.get_session("nonexistent-session-id")
    end
  end

  describe "revoke_session/1" do
    test "removes a session" do
      {:ok, session_id} = Manager.create_session("0xabc")

      assert :ok = Manager.revoke_session(session_id)
      assert {:error, :not_found} = Manager.get_session(session_id)
    end
  end

  describe "get_sessions/1" do
    test "returns all active sessions for an address" do
      Manager.create_session("0xtest", %{ttl_seconds: 3600})
      Manager.create_session("0xtest", %{ttl_seconds: 3600})

      sessions = Manager.get_sessions("0xtest")
      assert length(sessions) >= 2
    end
  end

  describe "revoke_all_sessions/1" do
    test "removes all sessions for an address" do
      Manager.create_session("0xbulk", %{ttl_seconds: 3600})
      Manager.create_session("0xbulk", %{ttl_seconds: 3600})

      assert :ok = Manager.revoke_all_sessions("0xbulk")
      assert Manager.get_sessions("0xbulk") == []
    end
  end
end
