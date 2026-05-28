defmodule Lux.LLM.PerplexityTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Perplexity
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "call/3" do
    test "makes correct API call and returns text response" do
      config = %{
        api_key: "test_pplx_key",
        model: "sonar"
      }

      Req.Test.expect(Perplexity, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/chat/completions"

        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert ["Bearer test_pplx_key"] = auth_header

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["model"] == "sonar"
        assert [%{"role" => "user", "content" => "What is the capital of France?"}] =
                 decoded_body["messages"]

        refute Map.has_key?(decoded_body, "return_citations")
        refute Map.has_key?(decoded_body, "search_recency_filter")

        Req.Test.json(conn, %{
          "id" => "resp-123",
          "model" => "sonar",
          "created" => 1_700_000_000,
          "choices" => [
            %{
              "message" => %{
                "role" => "assistant",
                "content" => ~s({"answer": "Paris"})
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{"prompt_tokens" => 10, "completion_tokens" => 5}
        })
      end)

      assert {:ok,
              %Signal{
                schema_id: ResponseSignal,
                payload: %{
                  content: %{"answer" => "Paris"},
                  finish_reason: "stop",
                  model: "sonar",
                  tool_calls: nil,
                  tool_calls_results: nil
                }
              }} = Perplexity.call("What is the capital of France?", [], config)
    end

    test "sends return_citations: true when configured" do
      config = %{
        api_key: "test_pplx_key",
        model: "sonar-pro",
        return_citations: true
      }

      Req.Test.expect(Perplexity, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["return_citations"] == true
        assert decoded_body["model"] == "sonar-pro"

        Req.Test.json(conn, %{
          "id" => "resp-456",
          "model" => "sonar-pro",
          "created" => 1_700_000_001,
          "choices" => [
            %{
              "message" => %{
                "role" => "assistant",
                "content" => ~s({"summary": "Paris is the capital."})
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{"prompt_tokens" => 12, "completion_tokens" => 8}
        })
      end)

      assert {:ok,
              %Signal{
                payload: %{
                  content: %{"summary" => "Paris is the capital."},
                  model: "sonar-pro"
                }
              }} = Perplexity.call("Tell me about Paris", [], config)
    end

    test "sends search_recency_filter when configured" do
      config = %{
        api_key: "test_pplx_key",
        model: "sonar",
        search_recency_filter: "week"
      }

      Req.Test.expect(Perplexity, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        decoded_body = Jason.decode!(body)

        assert decoded_body["search_recency_filter"] == "week"

        Req.Test.json(conn, %{
          "id" => "resp-789",
          "model" => "sonar",
          "created" => 1_700_000_002,
          "choices" => [
            %{
              "message" => %{
                "role" => "assistant",
                "content" => ~s({"news": "Latest events this week"})
              },
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{"prompt_tokens" => 8, "completion_tokens" => 10}
        })
      end)

      assert {:ok,
              %Signal{
                payload: %{
                  content: %{"news" => "Latest events this week"}
                }
              }} = Perplexity.call("What happened recently?", [], config)
    end

    test "returns :invalid_api_key on 401 response" do
      config = %{
        api_key: "bad_key",
        model: "sonar"
      }

      Req.Test.expect(Perplexity, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => %{"message" => "Unauthorized"}})
      end)

      assert {:error, :invalid_api_key} = Perplexity.call("Hello", [], config)
    end

    test "returns :rate_limited on 429 response" do
      config = %{
        api_key: "test_pplx_key",
        model: "sonar"
      }

      Req.Test.expect(Perplexity, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => %{"message" => "Too Many Requests"}})
      end)

      assert {:error, :rate_limited} = Perplexity.call("Hello", [], config)
    end
  end
end
