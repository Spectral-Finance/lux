defmodule Lux.Lenses.Discord.Guilds.ListPresencesTest do
  @moduledoc """
  Test suite for the ListPresences module.
  These tests verify the lens's ability to:
  - List member presences from a Discord guild
  - Handle pagination parameters
  - Process Discord API errors appropriately
  - Validate input/output schemas
  """

  use UnitAPICase, async: true
  alias Lux.Lenses.Discord.Guilds.ListPresences

  @guild_id "123456789012345678"
  @user_id "111222333444555666"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "focus/2" do
    test "successfully lists member presences" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id/presences"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        # Verify query parameters
        query = URI.decode_query(conn.query_string)
        assert query["limit"] == "100"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "user" => %{
              "id" => @user_id,
              "username" => "test_user"
            },
            "status" => "online",
            "activities" => [
              %{
                "name" => "Visual Studio Code",
                "type" => 0,
                "created_at" => 1_234_567_890
              }
            ],
            "client_status" => %{
              "desktop" => "online",
              "mobile" => "idle"
            }
          }
        ]))
      end)

      assert {:ok, [presence]} = ListPresences.focus(%{
        guild_id: @guild_id,
        limit: 100
      }, %{})

      assert presence.user.id == @user_id
      assert presence.user.username == "test_user"
      assert presence.status == "online"
      assert [activity] = presence.activities
      assert activity.name == "Visual Studio Code"
      assert activity.type == 0
      assert activity.created_at == 1_234_567_890
      assert presence.client_status.desktop == "online"
      assert presence.client_status.mobile == "idle"
    end

    test "successfully lists presences with pagination" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id/presences"

        # Verify pagination parameters
        query = URI.decode_query(conn.query_string)
        assert query["limit"] == "50"
        assert query["after"] == @user_id

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "user" => %{
              "id" => "222333444555666777",
              "username" => "next_user"
            },
            "status" => "idle",
            "activities" => [],
            "client_status" => %{
              "web" => "idle"
            }
          }
        ]))
      end)

      assert {:ok, [presence]} = ListPresences.focus(%{
        guild_id: @guild_id,
        limit: 50,
        after: @user_id
      }, %{})

      assert presence.user.username == "next_user"
      assert presence.status == "idle"
      assert presence.activities == []
      assert presence.client_status.web == "idle"
    end

    test "handles empty activities and client status" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id/presences"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!([
          %{
            "user" => %{
              "id" => @user_id,
              "username" => "test_user"
            },
            "status" => "offline"
          }
        ]))
      end)

      assert {:ok, [presence]} = ListPresences.focus(%{
        guild_id: @guild_id
      }, %{})

      assert presence.user.id == @user_id
      assert presence.status == "offline"
      assert presence.activities == []
      assert presence.client_status == %{}
    end

    test "handles Discord API error" do
      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/v10/guilds/:guild_id/presences"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, %{"message" => "Missing Permissions"}} = ListPresences.focus(%{
        guild_id: @guild_id
      }, %{})
    end
  end

  describe "schema validation" do
    test "validates required fields" do
      lens = ListPresences.view()
      assert lens.schema.required == ["guild_id"]
    end

    test "validates pagination parameters" do
      lens = ListPresences.view()

      # Verify limit parameter
      limit = lens.schema.properties.limit
      assert limit.type == :integer
      assert limit.minimum == 1
      assert limit.maximum == 1000
      assert limit.default == 100

      # Verify after parameter
      after_param = lens.schema.properties.after
      assert after_param.type == :string
      assert after_param.pattern == "^[0-9]{17,20}$"
    end
  end
end
