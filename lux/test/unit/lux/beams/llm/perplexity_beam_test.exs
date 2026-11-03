defmodule Lux.Beams.Llm.PerplexityBeamTest do
  use UnitAPICase, async: true

  alias Lux.Beams.Llm.Perplexity.PerplexityResearchBeam
  alias Lux.LLM.Perplexity

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "PerplexityResearchBeam" do
    test "verifies beam definition and metadata" do
      assert PerplexityResearchBeam.name() == "Perplexity Research Pipeline"
      assert is_map(PerplexityResearchBeam.input_schema())
      assert is_map(PerplexityResearchBeam.output_schema())
      assert PerplexityResearchBeam.input_schema().required == ["prompt"]
    end

    test "executes full research pipeline with domain filtering and citation formatting" do
      Req.Test.stub(Perplexity, fn conn ->
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        json = Jason.decode!(body)

        assert json["search_domain_filter"] == ["sec.gov"]

        Req.Test.json(conn, %{
          "model" => "sonar-pro",
          "choices" => [
            %{
              "finish_reason" => "stop",
              "message" => %{
                "role" => "assistant",
                "content" => "Ethereum Spot ETFs were approved in May 2024 [1]."
              }
            }
          ],
          "citations" => [
            "https://www.sec.gov/news/statement/2024-etf-approval"
          ]
        })
      end)

      inputs = %{
        prompt: "When were Ethereum Spot ETFs approved?",
        model: "sonar-pro",
        allowed_domains: ["sec.gov"],
        recency: "year",
        api_key: "sk-pplx"
      }

      assert {:ok, result, execution_log} = PerplexityResearchBeam.run(inputs)
      assert execution_log.status == :completed
      assert result.count == 1
      assert String.contains?(result.annotated_content, "### References")
      assert String.contains?(result.annotated_content, "sec.gov")
    end
  end
end
