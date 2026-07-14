defmodule Lux.Prisms.Telegram.Processing.ReplyParserTest do
  use ExUnit.Case, async: true
  
  alias Lux.Prisms.Telegram.Processing.ReplyParser

  describe "handler/2" do
    test "parses a reply message" do
      params = %{
        message: %{
          "reply_to_message" => %{
            "message_id" => 123,
            "from" => %{"id" => 456},
            "text" => "original message"
          }
        }
      }
      
      assert {:ok, result} = ReplyParser.handler(params, %{})
      assert result.is_reply == true
      assert result.replied_message_id == 123
      assert result.replied_user_id == 456
      assert result.replied_text == "original message"
      assert result.route_to == "reply_handler"
      assert result.reply_state == "in_context"
      assert result.planned_reply_action == %{type: "sendMessage", reply_to_message_id: 123}
    end
    
    test "parses a reply to a media message" do
      params = %{
        message: %{
          "reply_to_message" => %{
            "message_id" => 123,
            "from" => %{"id" => 456},
            "caption" => "original caption"
          }
        }
      }
      
      assert {:ok, result} = ReplyParser.handler(params, %{})
      assert result.is_reply == true
      assert result.replied_text == "original caption"
      assert result.route_to == "reply_handler"
    end
    
    test "parses a non-reply message" do
      params = %{
        message: %{
          "text" => "hello"
        }
      }
      
      assert {:ok, result} = ReplyParser.handler(params, %{})
      assert result.is_reply == false
      assert result.replied_message_id == nil
      assert result.replied_user_id == nil
      assert result.replied_text == nil
      assert result.route_to == "default_handler"
      assert result.reply_state == "none"
      assert result.planned_reply_action == nil
    end
    
    test "handles missing message" do
      assert {:error, _} = ReplyParser.handler(%{}, %{})
    end
  end
end
