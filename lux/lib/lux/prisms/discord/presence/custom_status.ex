defmodule Lux.Prisms.Discord.Presence.CustomStatus do
  @moduledoc """
  A prism for building Discord custom status activities.

  Creates type-4 custom status activities with optional emoji support.

  ## Examples

      iex> CustomStatus.handler(%{text: "Building things"}, %{name: "Agent"})
      {:ok, %{activity: %{name: "Custom Status", type: 4, state: "Building things"}}}

  """

  use Lux.Prism,
    name: "Set Discord Custom Status",
    description: "Builds a custom status activity (type 4)",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{type: :string, description: "Status text (max 128 chars)", maxLength: 128},
        emoji_name: %{type: :string, description: "Emoji name"},
        emoji_id: %{type: :string, description: "Custom emoji ID"}
      },
      required: ["text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        activity: %{type: :object, description: "Custom status activity map"}
      },
      required: ["activity"]
    }

  alias Lux.Integrations.Discord.Presence
  require Logger

  def handler(params, agent) do
    case Map.get(params, :text) do
      nil ->
        {:error, "Missing text parameter"}

      text when is_binary(text) and text != "" ->
        agent_name = agent[:name] || "Unknown Agent"
        Logger.info("Agent #{agent_name} setting custom status: #{text}")

        opts =
          []
          |> maybe_add(:emoji_name, Map.get(params, :emoji_name))
          |> maybe_add(:emoji_id, Map.get(params, :emoji_id))

        activity = Presence.custom_status(text, opts)
        Logger.info("Built custom status activity: #{inspect(activity)}")
        {:ok, %{activity: activity}}

      _ ->
        {:error, "Text must be a non-empty string"}
    end
  end

  defp maybe_add(opts, _key, nil), do: opts
  defp maybe_add(opts, key, value), do: Keyword.put(opts, key, value)
end
