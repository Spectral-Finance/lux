defmodule Lux.Prisms.Telegram.Processing.MessageThreadParserTest do
  use ExUnit.Case, async: true
  
  alias Lux.Prisms.Telegram.Processing.MessageThreadParser

  describe "handler/2" do
    test "parses a regular topic message" do
      params = %{
        message: %{
          "is_topic_message" => true,
          "message_thread_id" => 123
        }
      }
      
      assert {:ok, result} = MessageThreadParser.handler(params, %{})
      assert result.is_topic_message == true
      assert result.message_thread_id == 123
      assert result.is_topic_action == false
      assert result.thread_state == "active"
      assert result.route_to == "thread_message_handler"
      assert result.planned_reply_action == %{type: "sendMessage", target_thread_id: 123}
    end
    
    test "parses a topic action message" do
      params = %{
        message: %{
          "forum_topic_created" => %{"name" => "General"},
          "message_thread_id" => 123
        }
      }
      
      assert {:ok, result} = MessageThreadParser.handler(params, %{})
      assert result.is_topic_message == true
      assert result.message_thread_id == 123
      assert result.is_topic_action == true
      assert result.action_type == "created"
      assert result.thread_state == "active"
      assert result.route_to == "forum_management_handler"
      assert result.planned_reply_action == %{type: "sendMessage", target_thread_id: 123}
    end

    test "parses a closed topic message" do
      params = %{
        message: %{
          "forum_topic_closed" => %{},
          "message_thread_id" => 456
        }
      }
      
      assert {:ok, result} = MessageThreadParser.handler(params, %{})
      assert result.action_type == "closed"
      assert result.thread_state == "closed"
      assert result.route_to == "forum_management_handler"
    end
    
    test "parses a non-topic message" do
      params = %{
        message: %{
          "text" => "hello"
        }
      }
      
      assert {:ok, result} = MessageThreadParser.handler(params, %{})
      assert result.is_topic_message == false
      assert result.message_thread_id == nil
      assert result.is_topic_action == false
      assert result.action_type == nil
      assert result.thread_state == "none"
      assert result.route_to == "thread_message_handler"
      assert result.planned_reply_action == nil
    end
    
    test "handles missing message" do
      assert {:error, _} = MessageThreadParser.handler(%{}, %{})
    end
  end
end
