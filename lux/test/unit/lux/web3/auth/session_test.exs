defmodule Lux.Web3.Auth.Session.Test do
  use ExUnit.Case, async: true
  @moduletag :unit

  alias Lux.Web3.Auth.Session

  setup do
    Session.init_store()
    :ok
  end

  describe "create/2" do
    test "creates a new session for an address" do
      assert {:ok, session} = Session.create("0x1234567890abcdef1234567890abcdef12345678")
      assert session.address == "0x1234567890abcdef1234567890abcdef12345678"
      assert String.length(session.session_id) > 0
      assert session.chain_id == 1
    end

    test "creates a session with custom scope and metadata" do
      assert {:ok, session} = Session.create("0x1234567890abcdef1234567890abcdef12345678",
        scope: ["trading", "yield"],
        metadata: %{source: "web"}
      )

      assert session.scope == ["trading", "yield"]
      assert session.metadata.source == "web"
    end

    test "normalizes addresses to lowercase" do
      assert {:ok, session} = Session.create("0xABC123DEF456")
      assert session.address == "0xabc123def456"
    end
  end

  describe "get/1" do
    test "retrieves an existing session" do
      {:ok, created} = Session.create("0x1234567890abcdef1234567890abcdef12345678")
      assert {:ok, session} = Session.get(created.session_id)
      assert session.session_id == created.session_id
    end

    test "returns error for non-existent session" do
      assert {:error, :not_found} = Session.get("nonexistent")
    end
  end

  describe "get_by_address/1" do
    test "returns all sessions for an address" do
      addr = "0xtest_session_addr123456789012345678901234"
      {:ok, s1} = Session.create(addr)
      {:ok, s2} = Session.create(addr)

      sessions = Session.get_by_address(addr)
      assert length(sessions) == 2
      ids = Enum.map(sessions, & &1.session_id)
      assert s1.session_id in ids
      assert s2.session_id in ids
    end
  end

  describe "refresh/2" do
    test "extends session expiration" do
      {:ok, session} = Session.create("0xtestyieldaddr")
      {:ok, refreshed} = Session.refresh(session.session_id)
      assert DateTime.compare(refreshed.expires_at, session.expires_at) == :gt
    end

    test "returns error for non-existent session" do
      assert {:error, :not_found} = Session.refresh("nonexistent")
    end
  end

  describe "delete/1" do
    test "removes a session" do
      {:ok, session} = Session.create("0xdeletetest")
      Session.delete(session.session_id)
      assert {:error, :not_found} = Session.get(session.session_id)
    end
  end

  describe "delete_all/1" do
    test "removes all sessions for an address" do
      addr = "0xdeletealltest"
      Session.create(addr)
      Session.create(addr)
      Session.delete_all(addr)
      assert Session.get_by_address(addr) == []
    end
  end

  describe "cleanup/0" do
    test "removes expired sessions" do
      addr = "0xcleanuptest"
      {:ok, session} = Session.create(addr, ttl: 0)
      Process.sleep(10)

      count = Session.cleanup()
      assert count >= 1
      assert {:error, _} = Session.get(session.session_id)
    end
  end
end
