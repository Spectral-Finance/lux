# LLM Provider Routing

Lux includes a stateless LLM provider registry for choosing a provider/model
before making an LLM call.

```elixir
{:ok, selection} =
  Lux.LLM.ProviderRegistry.select(Lux.LLM.ProviderRegistry.default_registry(), %{
    capabilities: [:chat, :tools],
    strategy: :cost,
    input_tokens: 1_000,
    output_tokens: 500
  })

selection.provider.id
selection.model
selection.fallback_chain
selection.estimated_cost
```

Applications can register custom providers without starting a process:

```elixir
registry =
  Lux.LLM.ProviderRegistry.default_registry()
  |> Lux.LLM.ProviderRegistry.register(%Lux.LLM.Provider{
    id: :local,
    module: MyApp.LocalLLM,
    default_model: "llama-local",
    models: %{
      "llama-local" => %{
        capabilities: [:chat],
        input_cost_per_1k: 0,
        output_cost_per_1k: 0,
        latency_ms: 100,
        quality: 0.5
      }
    }
  })
```

Agents can also call `Lux.Prisms.LLM.ProviderRouterPrism` as a normal Prism to
get a provider decision and fallback chain from a workflow.
