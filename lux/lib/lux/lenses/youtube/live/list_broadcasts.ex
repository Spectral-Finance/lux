defmodule Lux.Lenses.YouTube.Live.ListBroadcasts do
  @moduledoc """
  Lists YouTube live broadcasts and normalizes their lifecycle state.
  """

  alias Lux.Integrations.YouTube
  alias Lux.Integrations.YouTube.LiveStream

  use Lux.Lens,
    name: "List YouTube Live Broadcasts",
    description:
      "Lists YouTube live broadcasts for scheduling, monitoring, and transition planning",
    url: "https://www.googleapis.com/youtube/v3/liveBroadcasts",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        part: %{
          type: :string,
          description: "Comma-separated liveBroadcast resource parts",
          default: "snippet,status,contentDetails"
        },
        broadcast_status: %{
          type: :string,
          description: "Broadcast status filter",
          enum: ["all", "active", "completed", "upcoming"]
        },
        mine: %{
          type: :boolean,
          description: "Whether to return broadcasts owned by the authenticated user"
        },
        id: %{
          type: :string,
          description: "Comma-separated broadcast ids"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of broadcasts",
          minimum: 1,
          maximum: 50,
          default: 5
        }
      },
      required: []
    }

  def before_focus(params) do
    params
    |> Map.put_new(:part, "snippet,status,contentDetails")
    |> maybe_default_mine()
    |> rename(:broadcast_status, :broadcastStatus)
    |> rename(:max_results, :maxResults)
  end

  @impl true
  def after_focus(%{"items" => items}) do
    {:ok, Enum.map(items, &LiveStream.normalize_broadcast/1)}
  end

  def after_focus(%{"error" => error}), do: {:error, error}

  defp maybe_default_mine(%{id: _id} = params), do: params
  defp maybe_default_mine(params), do: Map.put_new(params, :mine, true)

  defp rename(params, from, to) do
    case Map.pop(params, from) do
      {nil, params} -> params
      {value, params} -> Map.put(params, to, value)
    end
  end
end
