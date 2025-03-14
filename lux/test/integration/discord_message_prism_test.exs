defmodule Lux.Integration.DiscordMessagePrismTest do
  use IntegrationCase, async: true

  alias Lux.Prisms.Discord.MessagePrism

  @test_channel_id "123456789012345678"
  @test_content "Test message from Lux"
  @test_embed %{
    title: "Test Embed",
    description: "This is a test embed",
    color: 0x7289DA
  }

  describe "run/1" do
    test "successfully sends a simple message" do
      input = %{
        channel_id: @test_channel_id,
        content: @test_content
      }

      assert {:ok, result} = MessagePrism.run(input)
      assert result.status == "success"
      assert result.message.channel_id == @test_channel_id
      assert result.message.content == @test_content
      assert is_binary(result.message.id)
      assert is_binary(result.message.timestamp)
    end

    test "successfully sends a message with embed" do
      input = %{
        channel_id: @test_channel_id,
        content: @test_content,
        embeds: [@test_embed]
      }

      assert {:ok, result} = MessagePrism.run(input)
      assert result.status == "success"
      assert result.message.channel_id == @test_channel_id
      assert result.message.content == @test_content
    end

    test "returns error for invalid channel ID" do
      input = %{
        channel_id: "invalid",
        content: @test_content
      }

      assert {:error, _} = MessagePrism.run(input)
    end

    test "returns error for message too long" do
      input = %{
        channel_id: @test_channel_id,
        content: String.duplicate("a", 2001)
      }

      assert {:error, _} = MessagePrism.run(input)
    end

    test "returns error when Discord token is missing" do
      original_token = Application.get_env(:lux, :discord_token)
      Application.put_env(:lux, :discord_token, nil)

      input = %{
        channel_id: @test_channel_id,
        content: @test_content
      }

      assert {:error, _} = MessagePrism.run(input)

      Application.put_env(:lux, :discord_token, original_token)
    end

    test "returns error for invalid embed" do
      input = %{
        channel_id: @test_channel_id,
        content: @test_content,
        embeds: [%{
          title: String.duplicate("a", 257),  # Exceeds maxLength
          description: "Test description"
        }]
      }

      assert {:error, _} = MessagePrism.run(input)
    end
  end

  describe "before_handler/1" do
    test "correctly prepares request URL and body" do
      input = %{
        channel_id: @test_channel_id,
        content: @test_content,
        embeds: [@test_embed]
      }

      result = MessagePrism.before_handler(input)

      assert result.url =~ @test_channel_id
      assert result.body.content == @test_content
      assert length(result.body.embeds) == 1
      assert hd(result.body.embeds).title == @test_embed.title
    end
  end

  describe "handler/2" do
    test "handles successful response" do
      response = %{
        "id" => "987654321",
        "channel_id" => @test_channel_id,
        "content" => @test_content,
        "timestamp" => "2024-03-08T12:34:56Z"
      }

      assert {:ok, result} = MessagePrism.handler(response, nil)
      assert result.status == "success"
      assert result.message.id == "987654321"
      assert result.message.content == @test_content
    end

    test "handles error response" do
      response = %{
        "code" => 50001,
        "message" => "Missing Access"
      }

      assert {:error, "Discord API Error: Missing Access"} = MessagePrism.handler(response, nil)
    end

    test "handles unexpected response format" do
      response = %{"unexpected" => "format"}

      assert {:error, message} = MessagePrism.handler(response, nil)
      assert message =~ "Unexpected response format"
    end
  end
end
