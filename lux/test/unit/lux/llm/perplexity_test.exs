defmodule Lux.LLM.PerplexityTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Perplexity
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  require Lux.Beam
  require Lux.Lens
  require Lux.Prism

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "call/3" do
    test "executes chat completion with citations extraction" do
      Req.Test.stub(Lux.LLM.Perplexity, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/chat/completions"

        assert {"authorization", "Bearer test_pplx_key"} in conn.req_headers

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        decoded = Jason.decode!(body)

        assert decoded["model"] == "sonar"
        assert decoded["return_citations"] == true
        assert decoded["search_domain_filter"] == ["github.com", "elixir-lang.org"]

        response = %{
          "id" => "pplx-987654",
          "model" => "sonar",
          "created" => 1_730_548_900,
          "choices" => [
            %{
              "finish_reason" => "stop",
              "message" => %{
                "role" => "assistant",
                "content" => "Here is real-time verified information about Lux agents [1]."
              }
            }
          ],
          "citations" => [
            "https://github.com/Spectral-Finance/lux"
          ],
          "usage" => %{
            "prompt_tokens" => 20,
            "completion_tokens" => 14,
            "total_tokens" => 34
          }
        }

        Plug.Conn.resp(conn, 200, Jason.encode!(response))
      end)

      config = %{
        endpoint: "https://api.perplexity.ai/chat/completions",
        api_key: "test_pplx_key",
        model: "sonar",
        search_domain_filter: ["github.com", "elixir-lang.org"]
      }

      assert {:ok, %Signal{} = signal} = Perplexity.call("What is Lux?", [], config)
      assert signal.payload.content =~ "Here is real-time verified information"
      assert signal.payload.citations == ["https://github.com/Spectral-Finance/lux"]
      assert signal.metadata.citations_count == 1
    end

    test "handles 401 unauthorized" do
      Req.Test.stub(Lux.LLM.Perplexity, fn conn ->
        Plug.Conn.resp(conn, 401, Jason.encode!(%{"error" => %{"message" => "Unauthorized: Invalid API Key"}}))
      end)

      config = %{
        endpoint: "https://api.perplexity.ai/chat/completions",
        api_key: "invalid_key"
      }

      assert {:error, :invalid_api_key} = Perplexity.call("Test", [], config)
    end

    test "handles 429 rate limited" do
      Req.Test.stub(Lux.LLM.Perplexity, fn conn ->
        Plug.Conn.resp(conn, 429, Jason.encode!(%{"error" => %{"message" => "Rate limit exceeded"}}))
      end)

      config = %{
        endpoint: "https://api.perplexity.ai/chat/completions",
        api_key: "rate_limited_key"
      }

      assert {:error, :rate_limited} = Perplexity.call("Test", [], config)
    end
  end
end
