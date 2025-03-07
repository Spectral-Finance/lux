defmodule Lux.LLM.AnthropicTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Anthropic

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "call/3" do
    test "successfully calls Anthropic API" do
      Req.Test.expect(Anthropic, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/messages"

        auth_header = Plug.Conn.get_req_header(conn, "x-api-key")
        assert ["test_api_key"] = auth_header

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "claude-3-opus-20240229"
        assert [%{"role" => "user", "content" => "Hello, Claude!"}] = decoded_body["messages"]

        Req.Test.json(conn, %{
          "id" => "msg_123456",
          "type" => "message",
          "role" => "assistant",
          "content" => [
            %{
              "type" => "text",
              "text" => "This is a test response from Claude."
            }
          ],
          "model" => "claude-3-opus-20240229",
          "stop_reason" => "end_turn"
        })
      end)

      result =
        Anthropic.call("Hello, Claude!", [], %{
          api_key: "test_api_key",
          model: "claude-3-opus-20240229"
        })

      assert {:ok, response} = result
      assert response.content == "This is a test response from Claude."
      assert response.finish_reason == "end_turn"
    end

    test "handles API error" do
      Req.Test.expect(Anthropic, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(400, Jason.encode!(%{
          "error" => %{
            "type" => "invalid_request_error",
            "message" => "Invalid API key"
          },
          "type" => "error"
        }))
      end)

      result =
        Anthropic.call("Hello, Claude!", [], %{
          api_key: "invalid_api_key",
          model: "claude-3-opus-20240229"
        })

      assert {:error, error_message} = result
      assert error_message =~ "Error calling Anthropic API"
    end

    test "handles network error" do
      Req.Test.expect(Anthropic, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      result =
        Anthropic.call("Hello, Claude!", [], %{
          api_key: "test_api_key",
          model: "claude-3-opus-20240229"
        })

      assert {:error, error_message} = result
      assert error_message =~ "Error calling Anthropic API"
      assert error_message =~ "econnrefused"
    end

    test "supports tool calling" do
      test_tool = Lux.Prism.new(%{
        name: "test_tool",
        description: "A test tool",
        input_schema: %{
          "properties" => %{
            "param1" => %{
              "type" => "string",
              "description" => "Parameter 1"
            },
            "param2" => %{
              "type" => "string",
              "description" => "Parameter 2"
            }
          }
        }
      })

      Req.Test.expect(Anthropic, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["tools"] != nil

        Req.Test.json(conn, %{
          "id" => "msg_123456",
          "type" => "message",
          "role" => "assistant",
          "content" => [
            %{
              "type" => "tool_use",
              "id" => "tu_123456",
              "name" => "test_tool",
              "input" => %{
                "param1" => "value1",
                "param2" => "value2"
              }
            }
          ],
          "model" => "claude-3-opus-20240229",
          "stop_reason" => "tool_use"
        })
      end)

      result =
        Anthropic.call("Use the test tool", [test_tool], %{
          api_key: "test_api_key",
          model: "claude-3-opus-20240229"
        })

      assert {:ok, response} = result
      assert length(response.tool_calls) == 1
      [tool_call] = response.tool_calls
      assert tool_call.name == "test_tool"
      assert tool_call.params == %{"param1" => "value1", "param2" => "value2"}
    end
  end
end
