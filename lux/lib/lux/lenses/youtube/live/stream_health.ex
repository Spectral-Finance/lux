defmodule Lux.Lenses.YouTube.Live.StreamHealth do
  @moduledoc """
  Fetches and normalizes YouTube live stream health.
  """

  alias Lux.Integrations.YouTube
  alias Lux.Integrations.YouTube.LiveStream

  use Lux.Lens,
    name: "YouTube Live Stream Health",
    description: "Returns live stream status, health status, and configuration issues",
    url: "https://www.googleapis.com/youtube/v3/liveStreams",
    method: :get,
    headers: YouTube.headers(),
    auth: YouTube.auth(),
    schema: %{
      type: :object,
      properties: %{
        id: %{
          type: :string,
          description: "Comma-separated YouTube live stream ids"
        },
        mine: %{
          type: :boolean,
          description: "Whether to return streams owned by the authenticated user"
        },
        part: %{
          type: :string,
          description: "Comma-separated liveStream resource parts",
          default: "snippet,cdn,status"
        },
        max_results: %{
          type: :integer,
          description: "Maximum number of streams",
          minimum: 1,
          maximum: 50,
          default: 5
        }
      },
      required: []
    }

  def before_focus(params) do
    params
    |> Map.put_new(:part, "snippet,cdn,status")
    |> rename(:max_results, :maxResults)
  end

  @impl true
  def after_focus(%{"items" => items}) do
    {:ok, Enum.map(items, &LiveStream.normalize_stream/1)}
  end

  def after_focus(%{"error" => error}), do: {:error, error}

  defp rename(params, from, to) do
    case Map.pop(params, from) do
      {nil, params} -> params
      {value, params} -> Map.put(params, to, value)
    end
  end
end
