defmodule Lux.LLM.PerplexityTest do
  use UnitAPICase, async: true

  alias Lux.LLM.Perplexity
  alias Lux.LLM.Perplexity.Citations
  alias Lux.LLM.Perplexity.ModelRouter
  alias Lux.LLM.ResponseSignal
  alias Lux.Signal

  require Lux.Beam
  require Lux.Lens
  require Lux.Prism

  defmodule PplxTestPrism do
    @moduledoc false
    use Lux.Prism,
      name: "Perplexity Test Prism",
      input_schema: %{type: :object, properties: %{query: %{type: :string}}},
      description: "A test prism"

    def handler(%{"query" => "valid"}, _context), do: {:ok, %{result: "valid query"}}
    def handler(%{"query" => "invalid"}, _context), do: {:error, "invalid query"}
  end

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "tool_to_function/1" do
    test "converts Beam to Perplexity function" do
      beam =
        Lux.Beam.new(
          name: "WebScraper",
          description: "Scrapes webpage",
          input_schema: %{
            type: "object",
            properties: %{"url" => %{type: "string"}}
          }
        )

      func = Perplexity.tool_to_function(beam)
      assert func.type == "function"
      assert func.function.name == "WebScraper"
    end

    test "converts Prism to Perplexity function" do
      prism = PplxTestPrism.view()
      func = Perplexity.tool_to_function(prism)
      assert func.type == "function"
      assert func.function.name == "Lux_LLM_PerplexityTest_PplxTestPrism"
    end
  end

  describe "call/3" do
    test "makes an API call with domain filter, returns ResponseSignal with citations" do
      Req.Test.stub(Perplexity, fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer pplx-test-key"]

        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        json = Jason.decode!(body)

        assert json["model"] == "sonar-pro"
        assert json["search_domain_filter"] == ["sec.gov", "-reddit.com"]
        assert json["return_citations"] == true

        Req.Test.json(conn, %{
          "id" => "pplx-12345",
          "model" => "sonar-pro",
          "created" => 1718000000,
          "choices" => [
            %{
              "finish_reason" => "stop",
              "message" => %{
                "role" => "assistant",
                "content" => "Ethereum staking guidance was clarified in 2024 [1]."
              }
            }
          ],
          "citations" => [
            "https://www.sec.gov/news/press-release/2024-123"
          ],
          "usage" => %{
            "prompt_tokens" => 30,
            "completion_tokens" => 20
          }
        })
      end)

      config = %{
        api_key: "pplx-test-key",
        model: "sonar-pro",
        search_domain_filter: ["sec.gov", "-reddit.com"]
      }

      assert {:ok, %Signal{} = signal} =
               Perplexity.call("Latest SEC staking guidance", [], config)

      assert signal.schema_id == ResponseSignal
      assert signal.payload.content == "Ethereum staking guidance was clarified in 2024 [1]."
      assert signal.metadata.citations == ["https://www.sec.gov/news/press-release/2024-123"]
      assert signal.metadata.cost_estimate.total_cost > 0.0
    end

    test "handles tool calling execution" do
      Req.Test.stub(Perplexity, fn conn ->
        Req.Test.json(conn, %{
          "id" => "pplx-tool-1",
          "model" => "sonar-pro",
          "choices" => [
            %{
              "finish_reason" => "tool_calls",
              "message" => %{
                "role" => "assistant",
                "content" => nil,
                "tool_calls" => [
                  %{
                    "function" => %{
                      "name" => "Lux_LLM_PerplexityTest_PplxTestPrism",
                      "arguments" => ~s({"query": "valid"})
                    }
                  }
                ]
              }
            }
          ]
        })
      end)

      assert {:ok, %Signal{} = signal} =
               Perplexity.call("Run test tool", [PplxTestPrism], %{api_key: "pplx-test-key"})

      assert signal.payload.tool_calls_results == [%{result: "valid query"}]
    end

    test "handles missing API key" do
      assert {:error, :missing_api_key} =
               Perplexity.call("Prompt", [], %{api_key: nil})
    end
  end

  describe "Citations" do
    test "parses citations and extracts domain" do
      urls = [
        "https://arxiv.org/abs/2401.0001",
        "https://github.com/ethereum/go-ethereum"
      ]

      citations = Citations.parse_citations(urls)
      assert length(citations) == 2
      assert hd(citations).domain == "arxiv.org"
      assert hd(citations).index == 1
    end

    test "formats citations into markdown footnotes" do
      urls = ["https://ethereum.org"]
      citations = Citations.parse_citations(urls)
      footnotes = Citations.format_footnotes(citations)
      assert footnotes == "[1]: https://ethereum.org \"ethereum.org\""
    end
  end

  describe "ModelRouter" do
    test "selects model according to strategy" do
      assert ModelRouter.select_model(:reasoning_pro) == "sonar-reasoning-pro"
      assert ModelRouter.select_model(:reasoning) == "sonar-reasoning"
      assert ModelRouter.select_model(:pro) == "sonar-pro"
      assert ModelRouter.select_model(:fast) == "sonar"
    end

    test "estimates cost including search queries" do
      cost = ModelRouter.estimate_cost("sonar-pro", 10_000, 2_000, 2)
      # 10k prompt * $3/1M = $0.03
      # 2k completion * $15/1M = $0.03
      # 2 searches * $5/1000 = $0.01
      # total = $0.07
      assert cost.prompt_cost == 0.03
      assert cost.completion_cost == 0.03
      assert cost.search_cost == 0.01
      assert cost.total_cost == 0.07
    end
  end
end
