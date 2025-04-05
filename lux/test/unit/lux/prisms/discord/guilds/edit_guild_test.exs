defmodule Lux.Prisms.Discord.Guilds.EditGuildTest do
  @moduledoc """
  Test suite for the EditGuild module.
  These tests verify the prism's ability to:
  - Modify basic guild settings
  - Handle icon image updates
  - Validate input parameters
  - Handle Discord API errors appropriately
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Guilds.EditGuild

  @guild_id "987654321098765432"
  @guild_name "Test Server"
  # 1x1 transparent PNG
  @test_icon "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully modifies guild name" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "PATCH"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["name"] == @guild_name

        response = %{
          "id" => @guild_id,
          "name" => @guild_name,
          "icon" => nil,
          "verification_level" => 0,
          "explicit_content_filter" => 0
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(response))
      end)

      assert {:ok, %{
        modified: true,
        guild_id: @guild_id,
        guild: %{
          "id" => @guild_id,
          "name" => @guild_name
        }
      }} = EditGuild.handler(
        %{
          guild_id: @guild_id,
          name: @guild_name,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "successfully updates guild icon" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["icon"] == @test_icon

        response = %{
          "id" => @guild_id,
          "name" => @guild_name,
          "icon" => "abc123def456",
          "verification_level" => 0,
          "explicit_content_filter" => 0
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(response))
      end)

      assert {:ok, %{
        modified: true,
        guild: %{"icon" => "abc123def456"}
      }} = EditGuild.handler(
        %{
          guild_id: @guild_id,
          icon: @test_icon,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "successfully updates multiple settings" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["name"] == @guild_name
        assert body_map["verification_level"] == 2
        assert body_map["explicit_content_filter"] == 1

        response = %{
          "id" => @guild_id,
          "name" => @guild_name,
          "verification_level" => 2,
          "explicit_content_filter" => 1
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(response))
      end)

      assert {:ok, %{modified: true}} = EditGuild.handler(
        %{
          guild_id: @guild_id,
          name: @guild_name,
          verification_level: 2,
          explicit_content_filter: 1,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "handles Discord API errors" do
      error_response = %{
        "code" => 50_013,
        "message" => "Missing Permissions"
      }

      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(error_response))
      end)

      assert {:error, {403, error_response}} = EditGuild.handler(
        %{
          guild_id: @guild_id,
          name: @guild_name,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "fails when guild_id is missing" do
      assert {:error, "Missing or invalid guild_id"} = EditGuild.handler(
        %{
          name: @guild_name
        },
        @agent_ctx
      )
    end

    test "fails when no fields to update" do
      assert {:error, "No valid fields to update"} = EditGuild.handler(
        %{
          guild_id: @guild_id
        },
        @agent_ctx
      )
    end

    test "fails when verification_level is invalid" do
      assert {:error, error} = EditGuild.handler(
        %{
          guild_id: @guild_id,
          verification_level: 999
        },
        @agent_ctx
      )
      assert error =~ "verification_level"
    end
  end
end
