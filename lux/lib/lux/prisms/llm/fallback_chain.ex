defmodule Lux.Prisms.Llm.FallbackChainPrism do
  @moduledoc """
  Generates an ordered provider fallback execution chain based on operational preferences.
  """

  use Lux.Prism,
    name: "LLM Fallback Chain",
    description: "Constructs prioritized provider cascade for robust LLM failover",
    input_schema: %{
      type: :object,
      properties: %{
        primary_provider: %{type: :string, default: "openai"},
        backup_providers: %{type: :array, default: ["anthropic", "together_ai", "groq"]}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        chain: %{type: :array},
        primary: %{type: :string},
        total_providers: %{type: :integer}
      },
      required: ["chain", "primary", "total_providers"]
    }

  def handler(input, _ctx) do
    primary = Map.get(input, :primary_provider) || Map.get(input, "primary_provider", "openai")
    backups = Map.get(input, :backup_providers) || Map.get(input, "backup_providers", ["anthropic", "together_ai", "groq"])

    chain =
      ([primary | backups])
      |> Enum.map(&to_string/1)
      |> Enum.map(&String.downcase/1)
      |> Enum.uniq()

    {:ok,
     %{
       chain: chain,
       primary: primary,
       total_providers: length(chain)
     }}
  end
end
