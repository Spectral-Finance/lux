defmodule Lux.Prisms.YouTube.TransitionBroadcast do
  @moduledoc """
  A prism for transitioning a YouTube live broadcast between states.

  Manages the broadcast lifecycle:
  1. `testing` — Stream is live but visible only to the broadcaster
  2. `live` — Stream is publicly visible
  3. `complete` — Broadcast is ended

  The stream must be healthy (status: "active") before transitioning to `live`.

  ## Authentication

  Requires OAuth2 token with `youtube` scope.

      config :lux, :api_keys, youtube_oauth_token: "your_oauth2_token"

  ## Examples

      iex> TransitionBroadcast.handler(%{
      ...>   broadcast_id: "broadcastId...",
      ...>   broadcast_status: "live"
      ...> }, %{name: "Agent"})
      {:ok, %{
        broadcast_id: "broadcastId...",
        new_status: "live",
        title: "My Live Stream"
      }}
  """

  use Lux.Prism,
    name: "Transition YouTube Broadcast",
    description: "Transitions a broadcast between testing, live, and complete states",
    input_schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{
          type: :string,
          description: "The broadcast ID to transition"
        },
        broadcast_status: %{
          type: :string,
          description: "Target status for the broadcast",
          enum: ["testing", "live", "complete"]
        }
      },
      required: ["broadcast_id", "broadcast_status"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{type: :string},
        new_status: %{type: :string},
        title: %{type: :string}
      }
    }

  alias Lux.Integrations.YouTube

  @transition_url "https://www.googleapis.com/youtube/v3/liveBroadcasts/transition"

  @impl true
  def handler(params, _agent_ctx) do
    broadcast_id = params["broadcast_id"] || params[:broadcast_id]
    target_status = params["broadcast_status"] || params[:broadcast_status]

    oauth_token = Application.get_env(:lux, :api_keys)[:youtube_oauth_token]
    headers = YouTube.headers() ++ [{"Authorization", "Bearer #{oauth_token}"}]

    case Req.post(@transition_url,
      params: %{
        "id" => broadcast_id,
        "broadcastStatus" => target_status,
        "part" => "id,snippet,status"
      },
      headers: headers,
      body: ""
    ) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        snippet = body["snippet"] || %{}
        life_status = get_in(body, ["status", "lifeCycleStatus"])

        {:ok, %{
          broadcast_id: body["id"],
          new_status: target_status,
          life_cycle_status: life_status,
          title: snippet["title"],
          actual_start_time: snippet["actualStartTime"],
          actual_end_time: snippet["actualEndTime"]
        }
        |> Enum.reject(fn {_k, v} -> is_nil(v) end)
        |> Map.new()}

      {:ok, %{body: %{"error" => %{"message" => msg}}}} ->
        {:error, %{message: msg}}

      {:error, reason} ->
        {:error, %{message: inspect(reason)}}
    end
  end
end
