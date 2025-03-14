defmodule Lux.Integration.DiscordMessageLensTest do
  use IntegrationCase, async: true

  alias Lux.Lenses.Discord.MessageLens

  @test_channel_id "123456789012345678"

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "run/1" do
    @tag :integration
    test "successfully fetches messages" do
      Req.Test.stub(Lux.Lens, fn conn ->
        assert conn.params["limit"] == 50
        assert conn.headers["Authorization"] =~ "Bot "

        Req.Test.json(conn, [%{
          "id" => "987654321",
          "content" => "Test message",
          "channel_id" => @test_channel_id,
          "author" => %{
            "id" => "111222333",
            "username" => "TestUser",
            "discriminator" => "1234"
          },
          "timestamp" => "2024-03-08T12:34:56Z",
          "attachments" => [],
          "reactions" => []
        }])
      end)

      assert {:ok, result} = MessageLens.run(%{
        channel_id: @test_channel_id,
        limit: 50
      })

      assert result.status == "success"
      assert length(result.messages) == 1
      assert result.channel_id == @test_channel_id

      message = hd(result.messages)
      assert message.id == "987654321"
      assert message.content == "Test message"
      assert message.author.username == "TestUser"
    end

    @tag :integration
    test "successfully fetches messages with before parameter" do
      Req.Test.stub(Lux.Lens, fn conn ->
        assert conn.params["before"] == "987654321012345678"
        assert conn.params["limit"] == 10
        Req.Test.json(conn, [])
      end)

      assert {:ok, result} = MessageLens.run(%{
        channel_id: @test_channel_id,
        limit: 10,
        before: "987654321012345678"
      })

      assert result.status == "success"
      assert is_list(result.messages)
    end

    @tag :integration
    test "successfully fetches messages with after parameter" do
      Req.Test.stub(Lux.Lens, fn conn ->
        assert conn.params["after"] == "987654321012345678"
        assert conn.params["limit"] == 10
        Req.Test.json(conn, [])
      end)

      assert {:ok, result} = MessageLens.run(%{
        channel_id: @test_channel_id,
        limit: 10,
        after: "987654321012345678"
      })

      assert result.status == "success"
      assert is_list(result.messages)
    end

    @tag :integration
    test "returns error for invalid channel ID" do
      Req.Test.stub(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "code" => 50004,
          "message" => "Invalid channel ID"
        }, status: 400)
      end)

      assert {:error, error} = MessageLens.run(%{
        channel_id: "invalid",
        limit: 50
      })

      assert error.type == "discord_api_error"
      assert error.code == 50004
      assert error.message == "Invalid channel ID"
    end

    @tag :integration
    test "returns error when Discord token is missing" do
      original_token = Application.get_env(:lux, :discord_token)
      Application.put_env(:lux, :discord_token, nil)

      assert_raise ArgumentError, fn ->
        MessageLens.run(%{
          channel_id: @test_channel_id,
          limit: 50
        })
      end

      Application.put_env(:lux, :discord_token, original_token)
    end

    @tag :integration
    test "returns error for invalid limit" do
      assert {:error, error} = MessageLens.run(%{
        channel_id: @test_channel_id,
        limit: 101  # Exceeds maximum
      })

      assert error.type == "validation_error"
      assert error.message =~ "limit"
    end

    @tag :integration
    test "handles rate limiting" do
      Req.Test.stub(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{
          "retry_after" => 5000,
          "message" => "You are being rate limited"
        }, status: 429)
      end)

      assert {:error, error} = MessageLens.run(%{
        channel_id: @test_channel_id,
        limit: 50
      })

      assert error.type == "rate_limit"
      assert error.retry_after == 5000
    end
  end

  describe "before_focus/1" do
    test "correctly prepares request URL and query params" do
      input = %{
        channel_id: @test_channel_id,
        limit: 30,
        before: "987654321012345678",
        after: "123456789012345678"
      }

      result = MessageLens.before_focus(input)

      assert result.url =~ @test_channel_id
      assert result.params.limit == 30
      assert result.params.before == "987654321012345678"
      assert result.params.after == "123456789012345678"
    end

    test "omits nil query params" do
      input = %{
        channel_id: @test_channel_id,
        limit: 50
      }

      result = MessageLens.before_focus(input)

      assert result.url =~ @test_channel_id
      assert result.params.limit == 50
      refute Map.has_key?(result.params, :before)
      refute Map.has_key?(result.params, :after)
    end
  end

  describe "after_focus/1" do
    test "transforms successful response" do
      response = [
        %{
          "id" => "987654321",
          "content" => "Test message",
          "channel_id" => @test_channel_id,
          "author" => %{
            "id" => "111222333",
            "username" => "TestUser",
            "discriminator" => "1234"
          },
          "timestamp" => "2024-03-08T12:34:56Z",
          "attachments" => [
            %{
              "id" => "attachment123",
              "filename" => "test.txt",
              "size" => 1234,
              "url" => "https://cdn.discord.com/test.txt",
              "proxy_url" => "https://media.discord.com/test.txt",
              "content_type" => "text/plain"
            }
          ],
          "reactions" => [
            %{
              "emoji" => %{
                "name" => "👍"
              },
              "count" => 1
            }
          ]
        }
      ]

      assert {:ok, result} = MessageLens.after_focus(response)
      assert result.status == "success"
      assert length(result.messages) == 1

      message = hd(result.messages)
      assert message.id == "987654321"
      assert message.content == "Test message"
      assert message.author.username == "TestUser"
      assert length(message.attachments) == 1
      assert length(message.reactions) == 1

      attachment = hd(message.attachments)
      assert attachment.filename == "test.txt"
      assert attachment.content_type == "text/plain"

      reaction = hd(message.reactions)
      assert reaction.emoji == "👍"
      assert reaction.count == 1
    end

    test "handles error response" do
      response = %{
        "code" => 50001,
        "message" => "Missing Access"
      }

      assert {:error, error} = MessageLens.after_focus(response)
      assert error.type == "discord_api_error"
      assert error.code == 50001
      assert error.message == "Missing Access"
      assert error.context.endpoint == "messages"
      assert error.context.method == "GET"
    end

    test "handles rate limit response" do
      response = %{
        "retry_after" => 5000,
        "message" => "You are being rate limited"
      }

      assert {:error, error} = MessageLens.after_focus(response)
      assert error.type == "rate_limit"
      assert error.retry_after == 5000
    end

    test "handles unexpected response format" do
      response = %{"unexpected" => "format"}

      assert {:error, error} = MessageLens.after_focus(response)
      assert error.type == "unexpected_response"
      assert error.message =~ "Unexpected response format"
      assert error.response == response
    end
  end
end
