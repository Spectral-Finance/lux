defmodule Lux.Prisms.Discord.Guilds.CreateStickerTest do
  @moduledoc """
  Test suite for the CreateSticker module.
  These tests verify the prism's ability to:
  - Create custom stickers in a Discord server
  - Handle different file formats (PNG, APNG, GIF, JPG/JPEG)
  - Validate file sizes and formats
  - Handle Discord API errors appropriately
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Guilds.CreateSticker

  @guild_id "987654321098765432"
  @sticker_name "test_sticker"
  @sticker_description "A test sticker"
  @sticker_tags "test,cool"
  # 1x1 transparent PNG
  @test_png "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
  # 1x1 transparent APNG
  @test_apng "data:image/apng;base64,UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA=="
  # 1x1 transparent GIF
  @test_gif "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"
  # 1x1 white JPEG
  @test_jpeg "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wAALCAABAAEBAREA/8QAJgABAAAAAAAAAAAAAAAAAAAAAxABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQAAPwBcAF//2Q=="
  # Large file that exceeds 512KB
  @large_file "data:image/png;base64," <> String.duplicate("A", 700_000)
  @agent_ctx %{name: "TestAgent"}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully creates a sticker with PNG" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/stickers"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["name"] == @sticker_name
        assert body_map["description"] == @sticker_description
        assert body_map["tags"] == @sticker_tags
        assert body_map["file"] == @test_png

        response = %{
          "id" => "123456789012345678",
          "name" => @sticker_name,
          "description" => @sticker_description,
          "tags" => @sticker_tags,
          "format_type" => 1
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(response))
      end)

      assert {:ok, %{
        created: true,
        guild_id: @guild_id,
        sticker: %{
          id: "123456789012345678",
          name: @sticker_name,
          description: @sticker_description,
          tags: @sticker_tags,
          format_type: 1
        }
      }} = CreateSticker.handler(
        %{
          guild_id: @guild_id,
          name: @sticker_name,
          description: @sticker_description,
          tags: @sticker_tags,
          file: @test_png,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "successfully creates a sticker with APNG" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["file"] == @test_apng

        response = %{
          "id" => "123456789012345678",
          "name" => @sticker_name,
          "description" => @sticker_description,
          "tags" => @sticker_tags,
          "format_type" => 2
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(response))
      end)

      assert {:ok, %{sticker: %{format_type: 2}}} = CreateSticker.handler(
        %{
          guild_id: @guild_id,
          name: @sticker_name,
          description: @sticker_description,
          tags: @sticker_tags,
          file: @test_apng,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "successfully creates a sticker with GIF" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["file"] == @test_gif

        response = %{
          "id" => "123456789012345678",
          "name" => @sticker_name,
          "description" => @sticker_description,
          "tags" => @sticker_tags,
          "format_type" => 3
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(response))
      end)

      assert {:ok, %{sticker: %{format_type: 3}}} = CreateSticker.handler(
        %{
          guild_id: @guild_id,
          name: @sticker_name,
          description: @sticker_description,
          tags: @sticker_tags,
          file: @test_gif,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "successfully creates a sticker with JPEG" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["file"] == @test_jpeg

        response = %{
          "id" => "123456789012345678",
          "name" => @sticker_name,
          "description" => @sticker_description,
          "tags" => @sticker_tags,
          "format_type" => 4
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(response))
      end)

      assert {:ok, %{sticker: %{format_type: 4}}} = CreateSticker.handler(
        %{
          guild_id: @guild_id,
          name: @sticker_name,
          description: @sticker_description,
          tags: @sticker_tags,
          file: @test_jpeg,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "successfully creates a sticker without description" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        refute Map.has_key?(body_map, "description")

        response = %{
          "id" => "123456789012345678",
          "name" => @sticker_name,
          "tags" => @sticker_tags,
          "format_type" => 1
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(response))
      end)

      assert {:ok, %{sticker: %{description: nil}}} = CreateSticker.handler(
        %{
          guild_id: @guild_id,
          name: @sticker_name,
          tags: @sticker_tags,
          file: @test_png,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "handles Discord API errors" do
      error_body = %{
        "message" => "Missing Permissions",
        "code" => 50_013
      }

      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(error_body))
      end)

      assert {:error, {403, error_body}} = CreateSticker.handler(
        %{
          guild_id: @guild_id,
          name: @sticker_name,
          description: @sticker_description,
          tags: @sticker_tags,
          file: @test_png,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "fails when file is too large" do
      assert {:error, "File size " <> _} = CreateSticker.handler(
        %{
          guild_id: @guild_id,
          name: @sticker_name,
          tags: @sticker_tags,
          file: @large_file
        },
        @agent_ctx
      )
    end

    test "fails when guild_id is missing" do
      assert {:error, "Missing or invalid guild_id"} = CreateSticker.handler(
        %{
          name: @sticker_name,
          tags: @sticker_tags,
          file: @test_png
        },
        @agent_ctx
      )
    end

    test "fails when name is missing" do
      assert {:error, "Missing or invalid name"} = CreateSticker.handler(
        %{
          guild_id: @guild_id,
          tags: @sticker_tags,
          file: @test_png
        },
        @agent_ctx
      )
    end

    test "fails when tags is missing" do
      assert {:error, "Missing or invalid tags"} = CreateSticker.handler(
        %{
          guild_id: @guild_id,
          name: @sticker_name,
          file: @test_png
        },
        @agent_ctx
      )
    end
  end
end
