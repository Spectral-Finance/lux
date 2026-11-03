defmodule Lux.Prisms.LLM.CachePrism do
  @moduledoc """
  A prism for querying, populating, and managing the LLM prompt response cache.
  """

  use Lux.Prism,
    name: "LLM Cache Prism",
    description: "Queries and stores cached LLM completions to optimize latency and cost",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["get", "put", "stats", "clear"],
          default: "get"
        },
        prompt: %{type: :string},
        model: %{type: :string, default: "default"},
        content: %{type: :string},
        ttl_seconds: %{type: :integer, default: 3600}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        hit: %{type: :boolean},
        content: %{type: [:string, :null]},
        cache_key: %{type: [:string, :null]},
        stats: %{type: [:object, :null]}
      },
      required: ["hit"]
    }

  alias Lux.LLM.Cache
  alias Lux.LLM.Response

  @impl true
  def handler(inputs, _context) do
    action = Map.get(inputs, "action") || Map.get(inputs, :action, "get")
    prompt = Map.get(inputs, "prompt") || Map.get(inputs, :prompt, "")
    model = Map.get(inputs, "model") || Map.get(inputs, :model, "default")

    case action do
      "get" ->
        key = Cache.generate_key(prompt, model)

        case Cache.get(key) do
          {:ok, %Response{} = resp} ->
            {:ok, %{hit: true, content: resp.content, cache_key: key, stats: nil}}

          :miss ->
            {:ok, %{hit: false, content: nil, cache_key: key, stats: nil}}
        end

      "put" ->
        content = Map.get(inputs, "content") || Map.get(inputs, :content, "")
        ttl = Map.get(inputs, "ttl_seconds") || Map.get(inputs, :ttl_seconds, 3600)
        key = Cache.generate_key(prompt, model)
        Cache.put(key, %Response{content: content}, ttl)

        {:ok, %{hit: true, content: content, cache_key: key, stats: nil}}

      "clear" ->
        Cache.clear!()
        {:ok, %{hit: false, content: nil, cache_key: nil, stats: Cache.stats()}}

      "stats" ->
        {:ok, %{hit: false, content: nil, cache_key: nil, stats: Cache.stats()}}
    end
  end
end
