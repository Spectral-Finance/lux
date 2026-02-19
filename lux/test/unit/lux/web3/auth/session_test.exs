defmodule Lux.Web3.Auth.SessionTest do
  @moduledoc """
  Tests for the Session module covering session creation, retrieval,
  refresh, revocation, and automatic expiry.
  """

  use UnitCase

  alias Lux.Web3.Auth.Session

  @test_address "0x71C7656EC7ab88b098defB751B7401B5f6d8976F"
  @test_chain_id 1

  setup do
    # Start a session server with unique table/name for test isolation
    table_name = :"sessions_#{:erlang.unique_integer([:positive])}"
    name = :"session_server_#{:erlang.unique_integer([:positive])}"

    {:ok, pid} =
      Session.start_link(
        name: name,
        table_name: table_name,
        cleanup_interval: :timer.hours(1)
      )

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    %{server: name}
  end

  describe "create/2" do
    test "creates a session with required fields", %{server: server} do
      assert {:ok, session} =
               Session.create(
                 %{address: @test_address, chain_id: @test_chain_id},
                 server
               )

      assert session.address == @test_address
      assert session.chain_id == @test_chain_id
      assert session.roles == []
      assert session.metadata == %{}
      assert is_binary(session.token)
      assert %DateTime{} = session.created_at
      assert %DateTime{} = session.expires_at
    end

    test "creates a session with custom TTL", %{server: server} do
      assert {:ok, session} =
               Session.create(
                 %{address: @test_address, chain_id: @test_chain_id, ttl: 7200},
                 server
               )

      diff = DateTime.diff(session.expires_at, session.created_at)
      assert diff == 7200
    end

    test "creates a session with roles and metadata", %{server: server} do
      assert {:ok, session} =
               Session.create(
                 %{
                   address: @test_address,
                   chain_id: @test_chain_id,
                   roles: ["admin", "operator"],
                   metadata: %{domain: "example.com"}
                 },
                 server
               )

      assert session.roles == ["admin", "operator"]
      assert session.metadata == %{domain: "example.com"}
    end

    test "returns error for missing address", %{server: server} do
      assert {:error, _} =
               Session.create(%{chain_id: @test_chain_id}, server)
    end

    test "returns error for missing chain_id", %{server: server} do
      assert {:error, _} =
               Session.create(%{address: @test_address}, server)
    end

    test "generates unique tokens", %{server: server} do
      tokens =
        for _ <- 1..50 do
          {:ok, session} =
            Session.create(
              %{address: @test_address, chain_id: @test_chain_id},
              server
            )

          session.token
        end

      assert length(Enum.uniq(tokens)) == 50
    end
  end

  describe "get/2" do
    test "retrieves an existing session", %{server: server} do
      {:ok, created} =
        Session.create(
          %{address: @test_address, chain_id: @test_chain_id},
          server
        )

      assert {:ok, retrieved} = Session.get(created.token, server)
      assert retrieved.token == created.token
      assert retrieved.address == created.address
    end

    test "returns :not_found for unknown token", %{server: server} do
      assert {:error, :not_found} = Session.get("nonexistent-token", server)
    end

    test "returns :expired for expired session", %{server: server} do
      {:ok, session} =
        Session.create(
          %{address: @test_address, chain_id: @test_chain_id, ttl: 0},
          server
        )

      # Wait a moment for expiry
      Process.sleep(10)

      assert {:error, :expired} = Session.get(session.token, server)
    end
  end

  describe "refresh/3" do
    test "extends session expiry", %{server: server} do
      {:ok, session} =
        Session.create(
          %{address: @test_address, chain_id: @test_chain_id, ttl: 60},
          server
        )

      original_expires = session.expires_at

      {:ok, refreshed} = Session.refresh(session.token, 7200, server)

      assert DateTime.compare(refreshed.expires_at, original_expires) == :gt
    end

    test "returns :not_found for unknown token", %{server: server} do
      assert {:error, :not_found} = Session.refresh("nonexistent", 3600, server)
    end

    test "returns :expired for expired session", %{server: server} do
      {:ok, session} =
        Session.create(
          %{address: @test_address, chain_id: @test_chain_id, ttl: 0},
          server
        )

      Process.sleep(10)

      assert {:error, :expired} = Session.refresh(session.token, 3600, server)
    end
  end

  describe "revoke/2" do
    test "removes a session", %{server: server} do
      {:ok, session} =
        Session.create(
          %{address: @test_address, chain_id: @test_chain_id},
          server
        )

      assert :ok = Session.revoke(session.token, server)
      assert {:error, :not_found} = Session.get(session.token, server)
    end

    test "revoke of non-existent token succeeds silently", %{server: server} do
      assert :ok = Session.revoke("nonexistent", server)
    end
  end

  describe "revoke_all/2" do
    test "removes all sessions for an address", %{server: server} do
      # Create multiple sessions
      {:ok, s1} =
        Session.create(
          %{address: @test_address, chain_id: @test_chain_id},
          server
        )

      {:ok, s2} =
        Session.create(
          %{address: @test_address, chain_id: @test_chain_id},
          server
        )

      # Create session for different address
      {:ok, s3} =
        Session.create(
          %{
            address: "0x0000000000000000000000000000000000000001",
            chain_id: @test_chain_id
          },
          server
        )

      Session.revoke_all(@test_address, server)

      assert {:error, :not_found} = Session.get(s1.token, server)
      assert {:error, :not_found} = Session.get(s2.token, server)
      assert {:ok, _} = Session.get(s3.token, server)
    end
  end

  describe "list_by_address/2" do
    test "lists all active sessions for an address", %{server: server} do
      Session.create(
        %{address: @test_address, chain_id: @test_chain_id},
        server
      )

      Session.create(
        %{address: @test_address, chain_id: 137},
        server
      )

      sessions = Session.list_by_address(@test_address, server)
      assert length(sessions) == 2
      assert Enum.all?(sessions, &(&1.address == @test_address))
    end

    test "returns empty list for unknown address", %{server: server} do
      assert [] = Session.list_by_address("0x0000000000000000000000000000000000000099", server)
    end

    test "excludes expired sessions", %{server: server} do
      Session.create(
        %{address: @test_address, chain_id: @test_chain_id, ttl: 0},
        server
      )

      Session.create(
        %{address: @test_address, chain_id: @test_chain_id, ttl: 3600},
        server
      )

      Process.sleep(10)

      sessions = Session.list_by_address(@test_address, server)
      assert length(sessions) == 1
    end
  end

  describe "update_roles/3" do
    test "updates session roles", %{server: server} do
      {:ok, session} =
        Session.create(
          %{address: @test_address, chain_id: @test_chain_id},
          server
        )

      assert session.roles == []

      {:ok, updated} =
        Session.update_roles(session.token, ["admin", "operator"], server)

      assert updated.roles == ["admin", "operator"]

      # Verify persistence
      {:ok, retrieved} = Session.get(session.token, server)
      assert retrieved.roles == ["admin", "operator"]
    end

    test "returns :not_found for unknown session", %{server: server} do
      assert {:error, :not_found} =
               Session.update_roles("nonexistent", ["admin"], server)
    end

    test "returns :expired for expired session", %{server: server} do
      {:ok, session} =
        Session.create(
          %{address: @test_address, chain_id: @test_chain_id, ttl: 0},
          server
        )

      Process.sleep(10)

      assert {:error, :expired} =
               Session.update_roles(session.token, ["admin"], server)
    end
  end
end
