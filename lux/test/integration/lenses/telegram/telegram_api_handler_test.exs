defmodule Lux.Integration.Telegram.TelegramAPIHandlerTest do
  @moduledoc false
  use IntegrationCase, async: true

  alias Lux.Lenses.Telegram.TelegramAPIHandler
  alias Lux.Lenses.Telegram.SendMessage
  alias Lux.Lenses.Telegram.ForwardMessage

  # This test module assumes you have a valid Telegram bot token configured
  # and a chat ID where the bot can send messages

  setup do
    # Reset all rate limiters after each test
    TelegramAPIHandler.reset_all()

    # Get test chat ID from environment variable or use a default
    chat_id = System.get_env("TELEGRAM_TEST_CHAT_ID", "123456789")

    {:ok, %{chat_id: chat_id}}
  end

  describe "request_with_handling/3" do
    @tag :integration
    test "sends a message with rate limiting and retries", %{chat_id: chat_id} do
      # Skip if no bot token is set
      if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
        result = TelegramAPIHandler.request_with_handling(
          SendMessage,
          %{
            chat_id: chat_id,
            text: "Test message with rate limiting and retries"
          }
        )

        case result do
          {:ok, response} ->
            assert is_map(response)
            assert response.message_id
            assert response.text == "Test message with rate limiting and retries"

          {:error, error} ->
            flunk("Failed to send message: #{inspect(error)}")
        end
      end
    end

    @tag :integration
    test "forwards a message with rate limiting and retries", %{chat_id: chat_id} do
      # Skip if no bot token is set
      if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
        # First send a message to get a message_id
        {:ok, sent_message} = TelegramAPIHandler.request_with_handling(
          SendMessage,
          %{
            chat_id: chat_id,
            text: "Message to be forwarded"
          }
        )

        # Now forward that message
        result = TelegramAPIHandler.request_with_handling(
          ForwardMessage,
          %{
            chat_id: chat_id,
            from_chat_id: chat_id,
            message_id: sent_message.message_id
          }
        )

        case result do
          {:ok, response} ->
            assert is_map(response)
            assert response.message_id
            # The forward_from_chat field might be nil if the chat has privacy settings enabled
            # So we'll just check that the message was forwarded successfully
            assert response.message_id != sent_message.message_id

          {:error, error} ->
            flunk("Failed to forward message: #{inspect(error)}")
        end
      end
    end

    @tag :integration
    test "handles rate limiting when sending multiple messages quickly", %{chat_id: chat_id} do
      # Skip if no bot token is set
      if System.get_env("INTEGRATION_TELEGRAM_BOT_TOKEN") do
        # Send multiple messages in quick succession
        start_time = System.monotonic_time(:millisecond)

        results = for i <- 1..3 do
          TelegramAPIHandler.request_with_handling(
            SendMessage,
            %{
              chat_id: chat_id,
              text: "Rate limit test message #{i}"
            }
          )
        end

        end_time = System.monotonic_time(:millisecond)
        elapsed_time = end_time - start_time

        # Verify all messages were sent successfully
        for {status, response} <- results do
          assert status == :ok
          assert is_map(response)
          assert response.message_id
        end

        # Verify that rate limiting caused some delay
        # The exact delay depends on the rate limits, but it should be more than
        # just the time it takes to send 3 messages with no rate limiting
        assert elapsed_time > 500, "Rate limiting should have caused some delay"
      end
    end

    @tag :integration
    test "retries on temporary errors" do
      # Create a mock lens that fails on first attempt and succeeds on second
      defmodule MockLensWithTemporaryError do
        def focus(_params, _opts \\ []) do
          count = Process.get(:request_count, 0)
          Process.put(:request_count, count + 1)

          if count == 0 do
            {:error, "Bad Gateway"}
          else
            {:ok, %{message_id: 123, text: "Success after retry"}}
          end
        end
      end

      # Reset the counter
      Process.put(:request_count, 0)

      # Call the function with our mock lens
      result = TelegramAPIHandler.request_with_handling(
        MockLensWithTemporaryError,
        %{},
        [initial_delay: 100, max_delay: 200]
      )

      assert {:ok, response} = result
      assert response.message_id == 123
      assert response.text == "Success after retry"
      assert Process.get(:request_count) == 2  # Initial call + 1 retry
    end

    @tag :integration
    test "gives up after max retries on persistent errors" do
      # Create a mock lens that always fails
      defmodule MockLensWithPersistentError do
        def focus(_params, _opts \\ []) do
          count = Process.get(:request_count, 0)
          Process.put(:request_count, count + 1)

          {:error, "Bad Gateway"}
        end
      end

      # Reset the counter
      Process.put(:request_count, 0)

      # Call the function with our mock lens
      result = TelegramAPIHandler.request_with_handling(
        MockLensWithPersistentError,
        %{},
        [max_retries: 2, initial_delay: 100, max_delay: 200]
      )

      assert {:error, _} = result
      assert Process.get(:request_count) == 3  # Initial call + 2 retries
    end

    @tag :integration
    test "does not retry on non-retryable errors" do
      # Create a mock lens that fails with a non-retryable error
      defmodule MockLensWithNonRetryableError do
        def focus(_params, _opts \\ []) do
          count = Process.get(:request_count, 0)
          Process.put(:request_count, count + 1)

          {:error, "chat not found"}
        end
      end

      # Reset the counter
      Process.put(:request_count, 0)

      # Call the function with our mock lens
      result = TelegramAPIHandler.request_with_handling(
        MockLensWithNonRetryableError,
        %{}
      )

      assert {:error, _} = result
      assert Process.get(:request_count) == 1  # No retries
    end
  end
end
