defmodule Lux.Prisms.Llm.PerplexityPrismsTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Perplexity
  alias Lux.Prisms.Llm.Perplexity.CitationPrism
  alias Lux.Prisms.Llm.Perplexity.CostPrism
  alias Lux.Prisms.Llm.Perplexity.DomainFilterPrism
  alias Lux.Prisms.Llm.Perplexity.ReasoningPrism
  alias Lux.Prisms.Llm.Perplexity.SearchChatPrism

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "SearchChatPrism" do
    test "executes web research query and returns citations" do
      Req.Test.stub(Perplexity, fn conn ->
        Req.Test.json(conn, %{
          "model" => "sonar-pro",
          "choices" => [
            %{
              "finish_reason" => "stop",
              "message" => %{
                "role" => "assistant",
                "content" => "Arbitrum uses Nitro architecture."
              }
            }
          ],
          "citations" => ["https://arbitrum.io/nitro"],
          "usage" => %{"prompt_tokens" => 20, "completion_tokens" => 10}
        })
      end)

      inputs = %{
        "prompt" => "How does Arbitrum work?",
        "api_key" => "sk-pplx"
      }

      assert {:ok, result} = SearchChatPrism.handler(inputs, %{})
      assert result.content == "Arbitrum uses Nitro architecture."
      assert result.citations == ["https://arbitrum.io/nitro"]
    end
  end

  describe "ReasoningPrism" do
    test "executes reasoning with sonar-reasoning-pro" do
      Req.Test.stub(Perplexity, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        json = Jason.decode!(body)
        assert json["model"] == "sonar-reasoning-pro"

        Req.Test.json(conn, %{
          "model" => "sonar-reasoning-pro",
          "choices" => [
            %{
              "finish_reason" => "stop",
              "message" => %{"role" => "assistant", "content" => "Proof step 1... Q.E.D."}
            }
          ]
        })
      end)

      assert {:ok, result} =
               ReasoningPrism.handler(%{"prompt" => "Prove P != NP", "api_key" => "sk-pplx"}, %{})

      assert result.content == "Proof step 1... Q.E.D."
      assert result.model == "sonar-reasoning-pro"
    end
  end

  describe "CitationPrism" do
    test "formats citations and appends footnotes to content" do
      inputs = %{
        "citations" => ["https://github.com/ethereum/go-ethereum"],
        "content" => "Geth is the Go implementation of Ethereum."
      }

      assert {:ok, result} = CitationPrism.handler(inputs, %{})
      assert result.count == 1
      assert String.contains?(result.annotated_content, "### References")
      assert String.contains?(result.footnotes_markdown, "[1]: https://github.com/ethereum/go-ethereum")
    end
  end

  describe "DomainFilterPrism" do
    test "sanitizes allowed and blocked domains" do
      inputs = %{
        "allowed_domains" => ["https://arxiv.org/abs", "docs.lux.org"],
        "blocked_domains" => ["reddit.com"],
        "recency" => "month"
      }

      assert {:ok, result} = DomainFilterPrism.handler(inputs, %{})
      assert "arxiv.org" in result.search_domain_filter
      assert "docs.lux.org" in result.search_domain_filter
      assert "-reddit.com" in result.search_domain_filter
      assert result.search_recency_filter == "month"
    end
  end

  describe "CostPrism" do
    test "calculates prompt, completion, and search costs" do
      inputs = %{
        "model" => "sonar-pro",
        "prompt_tokens" => 50_000,
        "completion_tokens" => 10_000,
        "search_queries" => 5,
        "budget_limit" => 1.00
      }

      assert {:ok, result} = CostPrism.handler(inputs, %{})
      assert result.total_cost > 0.0
      assert result.budget_exceeded == false
    end
  end
end
