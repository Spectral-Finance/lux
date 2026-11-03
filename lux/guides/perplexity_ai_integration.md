# Perplexity AI Integration Guide

This guide covers the integration of Perplexity AI into the Lux framework, providing specialized online web grounding, real-time citation extraction, deep multi-step reasoning, and search domain filtering.

---

## 1. Overview & Architecture

Perplexity AI combines state-of-the-art LLMs with real-time web index search. Lux exposes this via a unified interface implementing the `Lux.LLM` behaviour with automatic citation parsing and token cost tracking.

```
+-----------------------------------------------------------------------+
|                              Lux Agent                                |
+-----------------------------------------------------------------------+
                                   |
                                   v
             +-------------------------------------------+
             | Lux.Beams.Llm.Perplexity.ResearchBeam     |
             +-------------------------------------------+
               /                 |                     \
              v                  v                      v
    +-------------------+ +-------------------+ +-------------------+
    | DomainFilterPrism | | SearchChatPrism   | | CitationPrism     |
    | (Allow/Block/Time)| | (Sonar Search)    | | (Footnotes & Ref) |
    +-------------------+ +-------------------+ +-------------------+
                                   |
                                   v
             +-------------------------------------------+
             | Lux.LLM.Perplexity (Behaviour: Lux.LLM)   |
             | - Domain Filtering (`search_domain_filter`)|
             | - Recency Limits (`search_recency_filter`)|
             | - Citations Array Parsing                 |
             | - Native Tool Calling (Beams / Prisms)    |
             +-------------------------------------------+
                                   |
                                   v
             +-------------------------------------------+
             | Perplexity API (api.perplexity.ai)        |
             |  /chat/completions                        |
             +-------------------------------------------+
```

---

## 2. Configuration

### Environment Variables

Configure your Perplexity API key:

```bash
export PERPLEXITY_API_KEY="pplx-..."
```

### Application Config

In `config/config.exs`:

```elixir
config :lux, :perplexity_models,
  default: "sonar-pro",
  fast: "sonar",
  reasoning: "sonar-reasoning-pro"
```

In `config/runtime.exs`:

```elixir
config :lux, :api_keys,
  perplexity: env!("PERPLEXITY_API_KEY", :string!, "missing perplexity")
```

---

## 3. Core Modules

### 3.1 `Lux.LLM.Perplexity`

Implements the standard `Lux.LLM` behaviour:

```elixir
# Basic web-grounded query
{:ok, signal} = Lux.LLM.Perplexity.call("What are the latest updates on Optimism Superchain?", [], %{
  model: "sonar-pro",
  temperature: 0.2
})

IO.puts(signal.payload.content)
IO.inspect(signal.metadata.citations)
```

#### Domain Filtering and Recency

Restrict web searches to verified authorities:

```elixir
{:ok, signal} = Lux.LLM.Perplexity.call("Latest governance proposal results", [], %{
  model: "sonar-pro",
  search_domain_filter: ["governance.aave.com", "snapshot.org", "-twitter.com"],
  search_recency_filter: "week"
})
```

#### Deep Reasoning Mode

Execute multi-step mathematical or logical derivations:

```elixir
{:ok, signal} = Lux.LLM.Perplexity.reason("Evaluate the security proofs of zk-SNARK vs zk-STARK")
```

---

### 3.2 `Lux.LLM.Perplexity.Citations`

Parses citation URLs into structured references and markdown footnotes:

```elixir
alias Lux.LLM.Perplexity.Citations

citations = Citations.parse_citations(["https://arxiv.org/abs/2401.1234"])
# => [%Citation{index: 1, url: "https://arxiv.org/abs/2401.1234", domain: "arxiv.org"}]

footnotes = Citations.format_footnotes(citations)
# => "[1]: https://arxiv.org/abs/2401.1234 \"arxiv.org\""
```

---

### 3.3 `Lux.LLM.Perplexity.ModelRouter`

Pricing calculations:

```elixir
alias Lux.LLM.Perplexity.ModelRouter

cost = ModelRouter.estimate_cost("sonar-pro", 15_000, 3_000, 1)
# => %{prompt_cost: 0.045, completion_cost: 0.045, search_cost: 0.005, total_cost: 0.095}
```

---

## 4. Dedicated Prisms

### `Lux.Prisms.Llm.Perplexity.SearchChatPrism`
Direct search query with citations:

```elixir
{:ok, result} = Lux.Prisms.Llm.Perplexity.SearchChatPrism.handler(%{
  "prompt" => "Analyze current liquid staking yields on Solana",
  "model" => "sonar-pro"
}, %{})
```

### `Lux.Prisms.Llm.Perplexity.ReasoningPrism`
Deep reasoning inference:

```elixir
{:ok, result} = Lux.Prisms.Llm.Perplexity.ReasoningPrism.handler(%{
  "prompt" => "Verify this smart contract invariant mathematically"
}, %{})
```

### `Lux.Prisms.Llm.Perplexity.CitationPrism`
Formats citations into markdown footnotes:

```elixir
{:ok, result} = Lux.Prisms.Llm.Perplexity.CitationPrism.handler(%{
  "citations" => ["https://ethereum.org"],
  "content" => "Ethereum proof of stake consensus."
}, %{})
```

### `Lux.Prisms.Llm.Perplexity.DomainFilterPrism`
Builds search filter rules:

```elixir
{:ok, filter} = Lux.Prisms.Llm.Perplexity.DomainFilterPrism.handler(%{
  "allowed_domains" => ["sec.gov", "bloomberg.com"],
  "blocked_domains" => ["reddit.com"],
  "recency" => "month"
}, %{})
```

---

## 5. End-to-End Research Pipeline Beam

The `Lux.Beams.Llm.Perplexity.PerplexityResearchBeam` coordinates:
1. Configuring domain filters and time windows.
2. Querying Perplexity Sonar with search grounding.
3. Automatically appending citation footnote references to output.

```elixir
{:ok, result, log} = Lux.Beams.Llm.Perplexity.PerplexityResearchBeam.run(%{
  prompt: "Synthesize latest Ethereum L2 roadmap",
  model: "sonar-pro",
  allowed_domains: ["ethereum.org", "vitalik.eth.limo"],
  recency: "month"
})

IO.puts(result.annotated_content)
```

---

## 6. Testing

Run ExUnit test suites:

```bash
mix test test/unit/lux/llm/perplexity_test.exs
mix test test/unit/lux/prisms/llm/perplexity_prisms_test.exs
mix test test/unit/lux/beams/llm/perplexity_beam_test.exs
```
