defmodule Lux.Prisms.Discord.Presence.BuildPresence do
  @moduledoc """
  A prism for building Discord Rich Presence payloads.

  Constructs Gateway-ready presence update payloads (opcode 3) with
  activity definitions, status, and metadata.

  ## Examples

      iex> BuildPresence.handler(%{status: :online, activities: [%{name: "Elixir", type: :playing}]}, %{name: "Agent"})
      {:ok, %{payload: %{op: 3, d: %{since: nil, activities: [...], status: "online", afk: false}}}}

  """

  use Lux.Prism,
    name: "Build Discord Presence",
    description: "Builds a Gateway presence update payload",
    input_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string, description: "Status: online, dnd, idle, invisible, offline"},
        activities: %{type: :array, description: "List of activity maps", items: %{type: :object}},
        since: %{type: [:integer, :null], description: "Unix timestamp (ms) of idle start"},
        afk: %{type: :boolean, description: "Whether the bot is AFK"}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        payload: %{type: :object, description: "Gateway opcode 3 payload"},
        status: %{type: :string},
        activity_count: %{type: :integer}
      },
      required: ["payload"]
    }

  alias Lux.Integrations.Discord.Presence
  require Logger

  def handler(params, agent) do
    agent_name = agent[:name] || "Unknown Agent"
    Logger.info("Agent #{agent_name} building Discord presence payload")

    opts = [
      status: Map.get(params, :status, :online),
      activities: Map.get(params, :activities, []) |> Enum.map(&normalize_activity/1),
      since: Map.get(params, :since),
      afk: Map.get(params, :afk, false)
    ]

    payload = Presence.gateway_presence_payload(opts)
    activity_count = length(get_in(payload, [:d, :activities]) || [])

    Logger.info("Built presence payload: status=#{payload.d.status}, #{activity_count} activities")
    {:ok, %{payload: payload, status: payload.d.status, activity_count: activity_count}}
  end

  defp normalize_activity(%{type: type} = activity) when is_atom(type), do: activity
  defp normalize_activity(%{"type" => type} = activity) do
    activity
    |> Map.delete("type")
    |> Map.put(:type, normalize_type(type))
  end

  defp normalize_activity(%{name: _} = activity), do: Map.put(activity, :type, :playing)
  defp normalize_activity(activity) when is_map(activity), do: Map.put(activity, :type, :playing)

  defp normalize_type(type) when is_atom(type), do: type
  defp normalize_type(type) when is_binary(type) do
    String.to_existing_atom(type)
  rescue
    ArgumentError -> :playing
  end
  defp normalize_type(_), do: :playing
end
