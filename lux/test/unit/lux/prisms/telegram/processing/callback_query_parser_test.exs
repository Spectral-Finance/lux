defmodule Lux.Prisms.Telegram.Processing.CallbackQueryParserTest do
  use ExUnit.Case, async: true
  
  alias Lux.Prisms.Telegram.Processing.CallbackQueryParser

  describe "handler/2" do
    test "parses a simple callback query" do
      params = %{
        callback_query: %{
          "id" => "123",
          "from" => %{"id" => 456},
          "data" => "like"
        }
      }
      
      assert {:ok, result} = CallbackQueryParser.handler(params, %{})
      assert result.id == "123"
      assert result.from_id == 456
      assert result.action == "like"
      assert result.params == %{}
      assert result.is_valid_payload == true
      assert result.route_to == "callback_handler"
      assert result.planned_actions == [%{type: "answerCallbackQuery", callback_query_id: "123"}]
    end
    
    test "parses a callback query with params" do
      params = %{
        callback_query: %{
          "id" => "123",
          "from" => %{"id" => 456},
          "data" => "buy:item=apple:qty=5"
        }
      }
      
      assert {:ok, result} = CallbackQueryParser.handler(params, %{})
      assert result.action == "buy"
      assert result.params == %{"item" => "apple", "qty" => "5"}
    end
    
    test "handles flag params" do
      params = %{
        callback_query: %{
          "id" => "123",
          "from" => %{"id" => 456},
          "data" => "settings:notifications:dark_mode=on"
        }
      }
      
      assert {:ok, result} = CallbackQueryParser.handler(params, %{})
      assert result.action == "settings"
      assert result.params == %{"notifications" => true, "dark_mode" => "on"}
    end

    test "rejects callback data exceeding 64 bytes limit" do
      long_data = String.duplicate("a", 65)
      params = %{
        callback_query: %{
          "id" => "123",
          "from" => %{"id" => 456},
          "data" => long_data
        }
      }
      
      assert {:error, "Callback data exceeds 64-byte limit"} = CallbackQueryParser.handler(params, %{})
    end
    
    test "handles missing callback_query" do
      assert {:error, _} = CallbackQueryParser.handler(%{}, %{})
    end
  end
end
