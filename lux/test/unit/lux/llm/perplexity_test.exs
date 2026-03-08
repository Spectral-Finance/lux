defmodule Lux.LLM.PerplexityTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Perplexity
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  require Lux.Prism

  defmodule TestPrism do
    @moduledoc false
    use Lux.Prism,
      name: "Test Prism",
      input_schema: %{type: :object, properties: %{value: %{type: :string}}},
      description: "A test prism"

    def handler(%{"value" => "success"}, _context), do: {:ok, %{result: "success test"}}
    def handler(%{"value" => "failure"}, _context), do: {:error, "failure test"}
  end

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "call/3" do
    test "sends a basic prompt and returns a valid signal" do
      Req.Test.expect(Lux.LLM.Perplexity, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["model"] == "sonar-pro"
        assert is_list(decoded["messages"])
        assert List.last(decoded["messages"])["role"] == "user"

        Req.Test.json(conn, %{
          "id" => "pplx-abc123",
          "choices" => [
            %{
              "message" => %{
                "role" => "assistant",
                "content" => Jason.encode!(%{"answer" => "Here is the latest news"})
              },
              "finish_reason" => "stop"
            }
          ],
          "model" => "sonar-pro",
          "usage" => %{
            "prompt_tokens" => 15,
            "completion_tokens" => 25,
            "total_tokens" => 40
          },
          "citations" => [
            "https://example.com/source1",
            "https://example.com/source2"
          ]
        })
      end)

      assert {:ok, %Signal{} = signal} =
               Perplexity.call("What's new in tech?", [], %{
                 model: "sonar-pro",
                 api_key: "test-key"
               })

      assert signal.schema_id == ResponseSignal
      assert signal.payload.content == %{"answer" => "Here is the latest news"}
      assert signal.payload.model == "sonar-pro"
      assert signal.payload.finish_reason == "stop"
      assert signal.metadata.citations == ["https://example.com/source1", "https://example.com/source2"]
    end

    test "includes search options in request body" do
      Req.Test.expect(Lux.LLM.Perplexity, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["return_citations"] == true
        assert decoded["return_images"] == true
        assert decoded["search_domain_filter"] == ["arxiv.org", "nature.com"]
        assert decoded["search_recency_filter"] == "week"

        Req.Test.json(conn, %{
          "id" => "pplx-search",
          "choices" => [
            %{
              "message" => %{"role" => "assistant", "content" => Jason.encode!(%{"result" => "found"})},
              "finish_reason" => "stop"
            }
          ],
          "model" => "sonar-pro",
          "usage" => %{"prompt_tokens" => 10, "completion_tokens" => 10, "total_tokens" => 20},
          "citations" => ["https://arxiv.org/paper1"],
          "images" => [%{"url" => "https://example.com/img.png"}]
        })
      end)

      assert {:ok, %Signal{} = signal} =
               Perplexity.call("Latest ML papers", [], %{
                 model: "sonar-pro",
                 api_key: "test-key",
                 return_citations: true,
                 return_images: true,
                 search_domain_filter: ["arxiv.org", "nature.com"],
                 search_recency_filter: "week"
               })

      assert signal.metadata.citations == ["https://arxiv.org/paper1"]
      assert signal.metadata.images == [%{"url" => "https://example.com/img.png"}]
    end

    test "includes related questions when returned" do
      Req.Test.expect(Lux.LLM.Perplexity, fn conn ->
        Req.Test.json(conn, %{
          "id" => "pplx-rq",
          "choices" => [
            %{
              "message" => %{"role" => "assistant", "content" => Jason.encode!(%{"ok" => true})},
              "finish_reason" => "stop"
            }
          ],
          "model" => "sonar-pro",
          "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 5, "total_tokens" => 10},
          "related_questions" => ["What is quantum computing?", "How does entanglement work?"]
        })
      end)

      assert {:ok, %Signal{} = signal} =
               Perplexity.call("Explain quantum", [], %{
                 model: "sonar-pro",
                 api_key: "test-key",
                 return_related_questions: true
               })

      assert signal.metadata.related_questions == ["What is quantum computing?", "How does entanglement work?"]
    end

    test "sends tools in the request" do
      Req.Test.expect(Lux.LLM.Perplexity, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert is_list(decoded["tools"])
        assert length(decoded["tools"]) == 1

        Req.Test.json(conn, %{
          "id" => "pplx-tools",
          "choices" => [
            %{
              "message" => %{
                "role" => "assistant",
                "content" => Jason.encode!(%{"result" => "tool done"}),
                "tool_calls" => nil
              },
              "finish_reason" => "stop"
            }
          ],
          "model" => "sonar-pro",
          "usage" => %{"prompt_tokens" => 15, "completion_tokens" => 10, "total_tokens" => 25}
        })
      end)

      assert {:ok, %Signal{}} =
               Perplexity.call("Use the tool", [TestPrism], %{
                 model: "sonar-pro",
                 api_key: "test-key"
               })
    end

    test "includes sampling parameters when set" do
      Req.Test.expect(Lux.LLM.Perplexity, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["top_p"] == 0.9
        assert decoded["top_k"] == 50
        assert decoded["presence_penalty"] == 0.5

        Req.Test.json(conn, %{
          "id" => "pplx-sample",
          "choices" => [
            %{
              "message" => %{"role" => "assistant", "content" => Jason.encode!(%{"ok" => true})},
              "finish_reason" => "stop"
            }
          ],
          "model" => "sonar-pro",
          "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 5, "total_tokens" => 10}
        })
      end)

      assert {:ok, %Signal{}} =
               Perplexity.call("test", [], %{
                 api_key: "test-key",
                 top_p: 0.9,
                 top_k: 50,
                 presence_penalty: 0.5
               })
    end

    test "returns error for invalid API key" do
      Req.Test.expect(Lux.LLM.Perplexity, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid API key"}})
      end)

      assert {:error, :invalid_api_key} =
               Perplexity.call("test", [], %{api_key: "bad-key"})
    end

    test "handles API error responses" do
      Req.Test.expect(Lux.LLM.Perplexity, fn conn ->
        conn
        |> Plug.Conn.put_status(400)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid model"}})
      end)

      assert {:error, {400, "Invalid model"}} =
               Perplexity.call("test", [], %{
                 api_key: "test-key",
                 model: "nonexistent"
               })
    end

    test "supports different model types" do
      Req.Test.expect(Lux.LLM.Perplexity, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["model"] == "sonar"

        Req.Test.json(conn, %{
          "id" => "pplx-model",
          "choices" => [
            %{
              "message" => %{"role" => "assistant", "content" => Jason.encode!(%{"ok" => true})},
              "finish_reason" => "stop"
            }
          ],
          "model" => "sonar",
          "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 5, "total_tokens" => 10}
        })
      end)

      assert {:ok, %Signal{} = signal} =
               Perplexity.call("test", [], %{
                 model: "sonar",
                 api_key: "test-key"
               })

      assert signal.payload.model == "sonar"
    end

    test "handles response without citations" do
      Req.Test.expect(Lux.LLM.Perplexity, fn conn ->
        Req.Test.json(conn, %{
          "id" => "pplx-nocite",
          "choices" => [
            %{
              "message" => %{"role" => "assistant", "content" => Jason.encode!(%{"answer" => "test"})},
              "finish_reason" => "stop"
            }
          ],
          "model" => "sonar-pro",
          "usage" => %{"prompt_tokens" => 5, "completion_tokens" => 5, "total_tokens" => 10}
        })
      end)

      assert {:ok, %Signal{} = signal} =
               Perplexity.call("test", [], %{api_key: "test-key"})

      refute Map.has_key?(signal.metadata, :citations)
    end
  end
end
