defmodule Lux.LLM.PerplexityTest do
  @moduledoc false
  use UnitAPICase, async: true

  alias Lux.LLM.Perplexity
  alias Lux.LLM.Response

  require Lux.Beam
  require Lux.Lens
  require Lux.Prism

  # ---------------------------------------------------------------------------
  # In-test fixtures
  # ---------------------------------------------------------------------------

  defmodule TestPrism do
    @moduledoc false
    use Lux.Prism,
      name: "test_search",
      description: "A test search prism",
      input_schema: %{
        type: :object,
        properties: %{query: %{type: :string, description: "Search query"}},
        required: ["query"]
      }

    def handler(%{"query" => _q}, _ctx), do: {:ok, %{results: ["result_1", "result_2"]}}
  end

  defmodule TestBeam do
    @moduledoc false
    use Lux.Beam,
      name: "test_pipeline",
      description: "A test pipeline beam",
      input_schema: %{type: :object, properties: %{value: %{type: :string}}}

    sequence do
      step(:search, TestPrism, %{})
    end
  end

  defmodule TestLens do
    @moduledoc false
    use Lux.Lens,
      name: "weather_lens",
      description: "Gets weather data",
      schema: %{
        type: "object",
        properties: %{
          location: %{type: "string", description: "City name"}
        },
        required: ["location"]
      }
  end

  setup do
    Req.Test.verify_on_exit!()
  end

  # ---------------------------------------------------------------------------
  # tool_to_function/1
  # ---------------------------------------------------------------------------

  describe "tool_to_function/1" do
    test "converts a Prism to an OpenAI-compatible function spec" do
      prism = TestPrism.view()
      result = Perplexity.tool_to_function(prism)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_PerplexityTest_TestPrism",
                 description: "A test search prism",
                 parameters: %{
                   type: :object,
                   properties: %{query: %{type: :string, description: "Search query"}},
                   required: ["query"]
                 }
               }
             } = result
    end

    test "converts a Beam to an OpenAI-compatible function spec" do
      beam = TestBeam.view()
      result = Perplexity.tool_to_function(beam)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_PerplexityTest_TestBeam",
                 description: "A test pipeline beam",
                 parameters: _
               }
             } = result
    end

    test "converts a Lens to an OpenAI-compatible function spec" do
      lens = TestLens.view()
      result = Perplexity.tool_to_function(lens)

      assert %{
               type: "function",
               function: %{
                 name: "Lux_LLM_PerplexityTest_TestLens",
                 description: "Gets weather data",
                 parameters: %{type: "object", properties: %{location: _}}
               }
             } = result
    end
  end

  # ---------------------------------------------------------------------------
  # call/3 — basic text response
  # ---------------------------------------------------------------------------

  describe "call/3 - basic text response" do
    test "successfully calls Perplexity API and returns text content" do
      Req.Test.expect(Perplexity, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/chat/completions"

        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer test_pplx_key"] = auth_header

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["model"] == "sonar"
        assert [%{"role" => "user", "content" => "What is the capital of France?"}] =
                 decoded["messages"]

        Req.Test.json(conn, %{
          "id" => "chatcmpl-abc123",
          "model" => "sonar",
          "object" => "chat.completion",
          "choices" => [
            %{
              "index" => 0,
              "finish_reason" => "stop",
              "message" => %{
                "role" => "assistant",
                "content" => "Paris"
              }
            }
          ],
          "usage" => %{
            "prompt_tokens" => 10,
            "completion_tokens" => 5,
            "total_tokens" => 15
          }
        })
      end)

      assert {:ok, %Response{} = resp} =
               Perplexity.call(
                 "What is the capital of France?",
                 [],
                 %{api_key: "test_pplx_key", model: "sonar"}
               )

      assert resp.content == "Paris"
      assert resp.finish_reason == "stop"
      assert resp.tool_calls == []
    end

    test "returns structured output including citations when present" do
      Req.Test.expect(Perplexity, fn conn ->
        Req.Test.json(conn, %{
          "id" => "chatcmpl-def456",
          "model" => "sonar",
          "choices" => [
            %{
              "index" => 0,
              "finish_reason" => "stop",
              "message" => %{
                "role" => "assistant",
                "content" => "Elixir was created by José Valim."
              }
            }
          ],
          "citations" => [
            "https://elixir-lang.org",
            "https://en.wikipedia.org/wiki/Elixir_(programming_language)"
          ],
          "usage" => %{"prompt_tokens" => 15, "completion_tokens" => 12, "total_tokens" => 27}
        })
      end)

      assert {:ok, %Response{structured_output: output}} =
               Perplexity.call(
                 "Who created Elixir?",
                 [],
                 %{api_key: "test_pplx_key", return_citations: true}
               )

      assert output[:citations] == [
               "https://elixir-lang.org",
               "https://en.wikipedia.org/wiki/Elixir_(programming_language)"
             ]
    end

    test "sends optional Perplexity-specific fields in request body" do
      Req.Test.expect(Perplexity, fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["search_recency_filter"] == "day"
        assert decoded["search_domain_filter"] == ["elixir-lang.org"]
        assert decoded["return_citations"] == true
        assert decoded["max_tokens"] == 512

        Req.Test.json(conn, %{
          "id" => "chatcmpl-ghi789",
          "model" => "sonar",
          "choices" => [
            %{
              "index" => 0,
              "finish_reason" => "stop",
              "message" => %{"role" => "assistant", "content" => "Recent news about Elixir."}
            }
          ]
        })
      end)

      assert {:ok, _resp} =
               Perplexity.call(
                 "Latest news about Elixir?",
                 [],
                 %{
                   api_key: "test_pplx_key",
                   return_citations: true,
                   search_recency_filter: "day",
                   search_domain_filter: ["elixir-lang.org"],
                   max_tokens: 512
                 }
               )
    end
  end

  # ---------------------------------------------------------------------------
  # call/3 — tool calling
  # ---------------------------------------------------------------------------

  describe "call/3 - tool calling" do
    test "sends tools in request body" do
      prism = TestPrism.view()

      Req.Test.expect(Perplexity, fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert [tool] = decoded["tools"]
        assert tool["type"] == "function"
        assert tool["function"]["name"] == "Lux_LLM_PerplexityTest_TestPrism"

        Req.Test.json(conn, %{
          "id" => "chatcmpl-tools1",
          "model" => "sonar",
          "choices" => [
            %{
              "index" => 0,
              "finish_reason" => "tool_calls",
              "message" => %{
                "role" => "assistant",
                "content" => nil,
                "tool_calls" => [
                  %{
                    "id" => "call_abc",
                    "type" => "function",
                    "function" => %{
                      "name" => "Lux_LLM_PerplexityTest_TestPrism",
                      "arguments" => ~s({"query": "Elixir 1.17 release notes"})
                    }
                  }
                ]
              }
            }
          ]
        })
      end)

      assert {:ok, %Response{} = resp} =
               Perplexity.call(
                 "Search for Elixir 1.17 release notes",
                 [prism],
                 %{api_key: "test_pplx_key"}
               )

      assert resp.finish_reason == "tool_calls"
      assert [tool_call] = resp.tool_calls
      assert tool_call.type == "function"
      assert tool_call.name == "Lux_LLM_PerplexityTest_TestPrism"
      assert tool_call.params == %{"query" => "Elixir 1.17 release notes"}
    end
  end

  # ---------------------------------------------------------------------------
  # call/3 — error handling
  # ---------------------------------------------------------------------------

  describe "call/3 - error handling" do
    test "returns {:error, :invalid_api_key} on 401" do
      Req.Test.expect(Perplexity, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(401, Jason.encode!(%{"error" => %{"message" => "Unauthorized"}}))
      end)

      assert {:error, :invalid_api_key} =
               Perplexity.call("hello", [], %{api_key: "bad_key"})
    end

    test "returns {:error, :forbidden} on 403" do
      Req.Test.expect(Perplexity, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(403, Jason.encode!(%{"error" => %{"message" => "Forbidden"}}))
      end)

      assert {:error, :forbidden} =
               Perplexity.call("hello", [], %{api_key: "restricted_key"})
    end

    test "returns {:error, {status, message}} on other API errors" do
      Req.Test.expect(Perplexity, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          429,
          Jason.encode!(%{
            "error" => %{"message" => "Rate limit exceeded"}
          })
        )
      end)

      assert {:error, {429, "Rate limit exceeded"}} =
               Perplexity.call("hello", [], %{api_key: "test_key"})
    end

    test "returns {:error, message} on network error" do
      Req.Test.expect(Perplexity, fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end)

      assert {:error, msg} = Perplexity.call("hello", [], %{api_key: "test_key"})
      assert msg =~ "Perplexity API error"
      assert msg =~ "econnrefused"
    end
  end

  # ---------------------------------------------------------------------------
  # parse_content/1
  # ---------------------------------------------------------------------------

  describe "parse_content/1" do
    test "returns nil for nil content" do
      assert {:ok, nil} = Perplexity.parse_content(nil)
    end

    test "returns raw string when content is not valid JSON" do
      assert {:ok, "plain text answer"} = Perplexity.parse_content("plain text answer")
    end

    test "decodes JSON string content into a map" do
      json = Jason.encode!(%{"answer" => 42})
      assert {:ok, %{"answer" => 42}} = Perplexity.parse_content(json)
    end
  end
end
