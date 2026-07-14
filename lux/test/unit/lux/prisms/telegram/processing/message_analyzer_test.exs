defmodule Lux.Prisms.Telegram.Processing.MessageAnalyzerTest do
  use ExUnit.Case, async: true
  
  alias Lux.Prisms.Telegram.Processing.MessageAnalyzer

  describe "handler/2" do
    test "analyzes a basic text message from a user" do
      params = %{
        message: %{
          "text" => "Hello",
          "from" => %{"is_bot" => false}
        }
      }
      
      assert {:ok, result} = MessageAnalyzer.handler(params, %{})
      assert result.is_reply == false
      assert result.is_forwarded == false
      assert result.content_types == ["text"]
      assert result.sender_type == "user"
      assert result.text == "Hello"
    end
    
    test "analyzes a message with photo and caption" do
      params = %{
        message: %{
          "photo" => [%{}],
          "caption" => "A photo",
          "from" => %{"is_bot" => false}
        }
      }
      
      assert {:ok, result} = MessageAnalyzer.handler(params, %{})
      assert result.content_types == ["photo"]
      assert result.text == "A photo"
    end
    
    test "analyzes a replied message from a bot" do
      params = %{
        message: %{
          "text" => "Reply",
          "from" => %{"is_bot" => true},
          "reply_to_message" => %{"message_id" => 123}
        }
      }
      
      assert {:ok, result} = MessageAnalyzer.handler(params, %{})
      assert result.is_reply == true
      assert result.sender_type == "bot"
    end
    
    test "analyzes a forwarded message from a channel" do
      params = %{
        message: %{
          "text" => "Forward",
          "sender_chat" => %{"type" => "channel"},
          "forward_date" => 123456
        }
      }
      
      assert {:ok, result} = MessageAnalyzer.handler(params, %{})
      assert result.is_forwarded == true
      assert result.sender_type == "channel"
    end
    
    test "handles missing message" do
      assert {:error, _} = MessageAnalyzer.handler(%{}, %{})
    end
  end
end
