defmodule Lux.Prisms.Discord.Guilds.CreateEmojiTest do
  @moduledoc """
  Test suite for the CreateEmoji module.
  These tests verify the prism's ability to:
  - Create custom emojis in a Discord server
  - Handle different image formats (PNG, JPEG, GIF, WebP) and sizes
  - Handle Discord API errors appropriately
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Guilds.CreateEmoji

  @guild_id "987654321098765432"
  @emoji_name "test_emoji"
  # 1x1 transparent PNG
  @test_image "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
  # 1x1 transparent WebP
  @test_webp "data:image/webp;base64,UklGRhoAAABXRUJQVlA4TA0AAAAvAAAAEAcQERGIiP4HAA=="
  # Large image that exceeds 256KB
  @large_image "data:image/png;base64," <> String.duplicate("A", 350_000)
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully creates an emoji with PNG" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/emojis"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["name"] == @emoji_name
        assert body_map["image"] == @test_image

        response = %{
          "id" => "123456789012345678",
          "name" => @emoji_name,
          "animated" => false
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(response))
      end)

      assert {:ok, %{
        created: true,
        guild_id: @guild_id,
        emoji: %{
          id: "123456789012345678",
          name: @emoji_name,
          animated: false
        }
      }} = CreateEmoji.handler(
        %{
          guild_id: @guild_id,
          name: @emoji_name,
          image: @test_image,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "successfully creates an emoji with WebP" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/api/v10/guilds/#{@guild_id}/emojis"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bot test-discord-token"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_map = Jason.decode!(body)
        assert body_map["name"] == @emoji_name
        assert body_map["image"] == @test_webp

        response = %{
          "id" => "123456789012345678",
          "name" => @emoji_name,
          "animated" => false
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, Jason.encode!(response))
      end)

      assert {:ok, %{
        created: true,
        guild_id: @guild_id,
        emoji: %{
          id: "123456789012345678",
          name: @emoji_name,
          animated: false
        }
      }} = CreateEmoji.handler(
        %{
          guild_id: @guild_id,
          name: @emoji_name,
          image: @test_webp,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "fails when image is too large" do
      assert {:error, "Image size " <> _} = CreateEmoji.handler(
        %{
          guild_id: @guild_id,
          name: @emoji_name,
          image: @large_image
        },
        @agent_ctx
      )
    end

    test "fails when guild_id is missing" do
      assert {:error, "Missing or invalid guild_id"} = CreateEmoji.handler(
        %{
          name: @emoji_name,
          image: @test_image
        },
        @agent_ctx
      )
    end

    test "fails when name is missing" do
      assert {:error, "Missing or invalid name"} = CreateEmoji.handler(
        %{
          guild_id: @guild_id,
          image: @test_image
        },
        @agent_ctx
      )
    end

    test "fails when image is missing" do
      assert {:error, "Missing or invalid image"} = CreateEmoji.handler(
        %{
          guild_id: @guild_id,
          name: @emoji_name
        },
        @agent_ctx
      )
    end

    test "fails when Discord returns a file size error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "code" => 50_045,
          "message" => "Image file size exceeds maximum of 256KB"
        }))
      end)

      assert {:error, _} = CreateEmoji.handler(
        %{
          guild_id: @guild_id,
          name: @emoji_name,
          image: @test_image,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end

    test "fails when Discord returns an error" do
      Req.Test.expect(DiscordClientMock, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{
          "code" => 50_013,
          "message" => "Missing Permissions"
        }))
      end)

      assert {:error, _} = CreateEmoji.handler(
        %{
          guild_id: @guild_id,
          name: @emoji_name,
          image: @test_image,
          plug: {Req.Test, DiscordClientMock}
        },
        @agent_ctx
      )
    end
  end
end
