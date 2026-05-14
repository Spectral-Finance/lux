defmodule Lux.Prisms.Discord.AdvancedFeatures do
  @moduledoc """
  Prism for advanced Discord voice, presence, webhook, and analytics plans.
  """

  use Lux.Prism,
    name: "Discord Advanced Features",
    description:
      "Builds Discord voice, rich presence, webhook, analytics, and combined advanced feature plans",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["voice", "presence", "webhook", "analytics", "advanced_plan"]
        },
        params: %{type: :object}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        result: %{type: :object}
      },
      required: ["status", "result"]
    }

  alias Lux.Integrations.Discord.AdvancedFeatures, as: Advanced

  def handler(%{action: "voice"} = input, _ctx),
    do: input |> params() |> Advanced.voice_channel_plan() |> normalize()

  def handler(%{action: "presence"} = input, _ctx),
    do: input |> params() |> Advanced.rich_presence_plan() |> normalize()

  def handler(%{action: "webhook"} = input, _ctx),
    do: input |> params() |> Advanced.webhook_plan() |> normalize()

  def handler(%{action: "analytics"} = input, _ctx) do
    params = params(input)

    params
    |> Map.get(:events, [])
    |> Advanced.analytics_report(Map.get(params, :options, %{}))
    |> normalize()
  end

  def handler(%{action: "advanced_plan"} = input, _ctx),
    do: input |> params() |> Advanced.advanced_feature_plan() |> normalize()

  def handler(_input, _ctx), do: {:error, "Unsupported Discord advanced operation"}

  defp params(input), do: Map.get(input, :params, %{})
  defp normalize({:ok, result}), do: {:ok, %{status: "success", result: result}}
  defp normalize({:error, reason}), do: {:error, reason}
end
