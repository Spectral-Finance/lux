defmodule Lux.Lenses.Discord.Analytics.GetServerOverviewTest do
  @moduledoc """
  Test suite for the GetServerOverview module.
  These tests verify the lens's ability to:
  - Retrieve server overview metrics
  - Process server data into meaningful statistics
  - Handle Discord API errors appropriately
  - Validate input parameters
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Analytics.GetServerOverview

  @guild_id "123456789012345678"
  @mock_response %{
    "id" => @guild_id,
    "name" => "Test Server",
    "description" => "A server for testing",
    "member_count" => 150,
    "channels" => [
      %{
        "id" => "111111111111111111",
        "name" => "General",
        "type" => 4,  # Category
        "position" => 0
      },
      %{
        "id" => "222222222222222222",
        "name" => "general",
        "type" => 0,  # Text
        "parent_id" => "111111111111111111",
        "position" => 0
      },
      %{
        "id" => "333333333333333333",
        "name" => "Voice Chat",
        "type" => 2,  # Voice
        "parent_id" => "111111111111111111",
        "position" => 1
      },
      %{
        "id" => "444444444444444444",
        "name" => "announcements",
        "type" => 5,  # Announcement
        "parent_id" => "111111111111111111",
        "position" => 2
      }
    ],
    "roles" => [
      %{
        "id" => "555555555555555555",
        "name" => "Admin",
        "color" => 16_711_680,  # Red
        "member_count" => 3
      },
      %{
        "id" => "666666666666666666",
        "name" => "Moderator",
        "color" => 65_280,  # Green
        "member_count" => 5
      }
    ]
  }

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully retrieves server overview metrics" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(@mock_response))
      end)

      assert {:ok, metrics} = GetServerOverview.focus(%{
        "guild_id" => @guild_id
      }, %{})

      # Verify server info
      assert metrics.server_info.id == @guild_id
      assert metrics.server_info.name == "Test Server"
      assert metrics.server_info.description == "A server for testing"
      assert metrics.server_info.member_count == 150
      assert String.match?(metrics.server_info.created_at, ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)

      # Verify channel statistics
      assert metrics.channels.total == 4
      assert metrics.channels.by_type.text == 1
      assert metrics.channels.by_type.voice == 1
      assert metrics.channels.by_type.category == 1
      assert metrics.channels.by_type.announcement == 1

      # Verify categories
      [category] = metrics.channels.categories
      assert category.name == "General"
      assert category.channels == ["general", "Voice Chat", "announcements"]

      # Verify roles
      assert length(metrics.roles) == 2
      [admin, mod] = metrics.roles
      assert admin.name == "Admin"
      assert admin.member_count == 3
      assert admin.color == 16_711_680
      assert mod.name == "Moderator"
      assert mod.member_count == 5
      assert mod.color == 65_280
    end

    test "handles empty server description" do
      response = %{@mock_response | "description" => nil}

      Req.Test.expect(Lux.Lens, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(response))
      end)

      assert {:ok, metrics} = GetServerOverview.focus(%{
        "guild_id" => @guild_id
      }, %{})

      assert metrics.server_info.description == ""
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} = GetServerOverview.focus(%{
        "guild_id" => @guild_id
      }, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = GetServerOverview.view()
      assert lens.schema.required == ["guild_id"]
    end

    test "validates guild ID format" do
      lens = GetServerOverview.view()
      guild_id = lens.schema.properties.guild_id
      assert guild_id.type == :string
      assert guild_id.pattern == "^[0-9]{17,20}$"
    end
  end
end
