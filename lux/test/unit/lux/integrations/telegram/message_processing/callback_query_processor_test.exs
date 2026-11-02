defmodule Lux.Integrations.Telegram.MessageProcessing.CallbackQueryProcessorTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.MessageProcessing.CallbackQueryProcessor

  describe "CallbackQueryProcessor" do
    test "parses callback query with delimited data" do
      query = %{
        "id" => "query_12345",
        "data" => "trade:buy:ETH:10",
        "from" => %{
          "id" => 555_444,
          "is_bot" => false,
          "first_name" => "Satoshi",
          "username" => "sat"
        },
        "message" => %{
          "message_id" => 800,
          "chat" => %{"id" => 123_456}
        }
      }

      assert {:ok, result} = CallbackQueryProcessor.parse(query)
      assert result.id == "query_12345"
      assert result.action == "trade"
      assert result.args == ["buy", "ETH", "10"]
      assert result.user.first_name == "Satoshi"
      assert result.chat_id == 123_456
      assert result.message_id == 800
    end

    test "encodes and decodes callback data adhering to 64 bytes" do
      assert {:ok, encoded} =
               CallbackQueryProcessor.encode_data("stake", ["0xabc", "100"])

      assert encoded == "stake:0xabc:100"

      decoded = CallbackQueryProcessor.decode_data(encoded)
      assert decoded.action == "stake"
      assert decoded.args == ["0xabc", "100"]

      # Payload exceeding 64 bytes returns error
      long_arg = String.duplicate("x", 65)
      assert {:error, {:callback_data_too_large, _}} =
               CallbackQueryProcessor.encode_data("too_long", [long_arg])
    end

    test "build_answer/2 creates valid parameters for answerCallbackQuery" do
      ans1 = CallbackQueryProcessor.build_answer("query_123")
      assert ans1.callback_query_id == "query_123"
      refute Map.has_key?(ans1, :text)

      ans2 =
        CallbackQueryProcessor.build_answer("query_123",
          text: "Trade executed successfully!",
          show_alert: true
        )

      assert ans2.callback_query_id == "query_123"
      assert ans2.text == "Trade executed successfully!"
      assert ans2.show_alert == true
    end
  end
end
