# Perplexity AI Integration

Lux provides a robust integration with Perplexity AI, giving your agents access to state-of-the-art chat completions and real-time web search with citations. 

## Configuration

To use the Perplexity AI lenses and prisms, you need to configure your API key in `config/config.exs`:

```elixir
config :lux, :api_keys,
  perplexity: System.get_env("PERPLEXITY_API_KEY")
```

## Available Lenses

The integration provides several lenses to interact with the Perplexity AI API.

### 1. Chat Completions (`Lux.Lenses.Perplexity.Chat`)

Sends messages to the Perplexity AI chat completions endpoint.

```elixir
alias Lux.Lenses.Perplexity.Chat

{:ok, result} = Chat.focus(%{
  model: "sonar-pro",
  messages: [
    %{role: "system", content: "You are a helpful assistant."},
    %{role: "user", content: "Explain quantum computing."}
  ]
})
```

### 2. Search (`Lux.Lenses.Perplexity.Search`)

A specialized lens that focuses on Perplexity's core competency: web search with citations.

```elixir
alias Lux.Lenses.Perplexity.Search

{:ok, result} = Search.focus(%{
  query: "What are the latest developments in Fusion Energy?",
  model: "sonar-deep-research"
})

# result.answer contains the summary
# result.citations contains a list of URLs used as sources
```

### 3. Models List (`Lux.Lenses.Perplexity.Models`)

Fetches the list of available models on your Perplexity AI account.

```elixir
alias Lux.Lenses.Perplexity.Models

{:ok, models_data} = Models.focus(%{})
```

## Available Prisms

Prisms wrap lenses into higher-level workflows. 

### Research Agent (`Lux.Prisms.Perplexity.ResearchAgent`)

The Research Agent prism automates investigating a topic at varying depths, compiling a summary along with the citations used.

```elixir
alias Lux.Prisms.Perplexity.ResearchAgent

{:ok, report} = ResearchAgent.run(%{
  topic: "Artificial General Intelligence timelines",
  depth: "comprehensive" # "basic" | "detailed" | "comprehensive"
})

IO.puts(report.summary)
IO.inspect(report.citations)
```

## Supported Models

We recommend using the `sonar` family of models for tasks that require real-time knowledge and citations:

- `sonar` (Fastest, good for basic queries)
- `sonar-pro` (Advanced, complex queries)
- `sonar-reasoning` (Chain-of-thought, problem solving)
- `sonar-deep-research` (Comprehensive web research)
