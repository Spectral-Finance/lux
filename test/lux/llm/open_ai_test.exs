defmodule Lux.LLM.OpenAITest do
  use ExUnit.Case, async: false

  setup do
    Req.Test.init([])
  end

  test "call/3 makes correct API call with tools" do
    Req.Test.expect("https://api.openai.com/v1/chat/completions", fn request ->
      assert request.method == :post
      assert request.headers["authorization"] == "Bearer test_key"
      assert request.headers["content-type"] == "application/json"

      assert request.body == %{
               "model" => "gpt-4-turbo-preview",
               "messages" => [%{"role" => "user", "content" => "test message"}],
               "tools" => [
                 %{
                   "type" => "function",
                   "function" => %{
                     "name" => "test_tool",
                     "description" => "A test tool"
                   }
                 }
               ]
             }

      %{
        status: 200,
        body: %{
          "choices" => [
            %{
              "message" => %{
                "content" => "test response",
                "role" => "assistant"
              },
              "finish_reason" => "stop"
            }
          ]
        }
      }
    end)

    {:ok, response} =
      Lux.LLM.OpenAI.call("test message", [%{name: "test_tool", description: "A test tool"}],
        config: [api_key: "test_key"]
      )

    assert response.content == "test response"
    assert response.model == "gpt-4-turbo-preview"
    assert response.finish_reason == "stop"
  end

  test "call/3 handles tool call responses" do
    Req.Test.expect("https://api.openai.com/v1/chat/completions", fn request ->
      assert request.method == :post
      assert request.headers["authorization"] == "Bearer test_key"
      assert request.headers["content-type"] == "application/json"

      %{
        status: 200,
        body: %{
          "choices" => [
            %{
              "message" => %{
                "content" => nil,
                "role" => "assistant",
                "tool_calls" => [
                  %{
                    "id" => "call_123",
                    "type" => "function",
                    "function" => %{
                      "name" => "test_tool",
                      "arguments" => "{\"arg1\":\"value1\"}"
                    }
                  }
                ]
              },
              "finish_reason" => "tool_calls"
            }
          ]
        }
      }
    end)

    {:ok, response} =
      Lux.LLM.OpenAI.call("test message", [%{name: "test_tool", description: "A test tool"}],
        config: [api_key: "test_key"]
      )

    assert response.tool_calls == [
             %{
               id: "call_123",
               type: "function",
               function: %{
                 name: "test_tool",
                 arguments: "{\"arg1\":\"value1\"}"
               }
             }
           ]

    assert response.model == "gpt-4-turbo-preview"
    assert response.finish_reason == "tool_calls"
  end

  test "call/3 handles API errors" do
    Req.Test.expect("https://api.openai.com/v1/chat/completions", fn _request ->
      %{
        status: 401,
        body: %{
          "error" => %{
            "message" => "Incorrect API key provided"
          }
        }
      }
    end)

    assert {:error, %{reason: "Incorrect API key provided"}} =
             Lux.LLM.OpenAI.call("test message", [], config: [api_key: "invalid_key"])
  end
end
