defmodule Lux.Prisms.Telegram.Processing.DeepLinkParserTest do
  use ExUnit.Case, async: true
  
  alias Lux.Prisms.Telegram.Processing.DeepLinkParser

  describe "handler/2" do
    test "parses a valid deep link" do
      params = %{text: "/start mypayload123"}
      assert {:ok, result} = DeepLinkParser.handler(params, %{})
      assert result.is_deep_link == true
      assert result.payload == "mypayload123"
    end
    
    test "parses targeted deep link" do
      params = %{text: "/start@bot_username mypayload123"}
      assert {:ok, result} = DeepLinkParser.handler(params, %{})
      assert result.is_deep_link == true
      assert result.payload == "mypayload123"
    end

    test "parses group deep link" do
      params = %{text: "/startgroup mypayload123"}
      assert {:ok, result} = DeepLinkParser.handler(params, %{})
      assert result.is_deep_link == true
      assert result.payload == "mypayload123"
    end

    test "parses targeted group deep link" do
      params = %{text: "/startgroup@bot_username mypayload123"}
      assert {:ok, result} = DeepLinkParser.handler(params, %{})
      assert result.is_deep_link == true
      assert result.payload == "mypayload123"
    end

    test "ignores regular start command" do
      params = %{text: "/start"}
      assert {:ok, result} = DeepLinkParser.handler(params, %{})
      assert result.is_deep_link == false
      assert result.payload == nil
    end
    
    test "ignores other commands" do
      params = %{text: "/help mypayload123"}
      assert {:ok, result} = DeepLinkParser.handler(params, %{})
      assert result.is_deep_link == false
      assert result.payload == nil
    end
    
    test "ignores plain text" do
      params = %{text: "hello world"}
      assert {:ok, result} = DeepLinkParser.handler(params, %{})
      assert result.is_deep_link == false
      assert result.payload == nil
    end
    
    test "handles missing text" do
      assert {:ok, result} = DeepLinkParser.handler(%{}, %{})
      assert result.is_deep_link == false
      assert result.payload == nil
    end
  end
end
