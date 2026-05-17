defmodule Lux.Prisms.YouTube.Live.TransitionBroadcast do
  @moduledoc """
  Transitions a YouTube live broadcast through testing, live, and complete states.
  """

  use Lux.Prism,
    name: "Transition YouTube Live Broadcast",
    description: "Transitions a YouTube live broadcast lifecycle state",
    input_schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{type: :string, description: "YouTube live broadcast id"},
        broadcast_status: %{
          type: :string,
          enum: ["testing", "live", "complete"],
          description: "Target broadcast lifecycle state"
        }
      },
      required: ["broadcast_id", "broadcast_status"]
    }

  alias Lux.Integrations.YouTube.Client
  alias Lux.Integrations.YouTube.LiveStream

  def handler(params, _agent) do
    with {:ok, broadcast_id} <- required(params, :broadcast_id),
         {:ok, broadcast_status} <- required(params, :broadcast_status) do
      opts = [
        token: params[:token],
        params: %{
          id: broadcast_id,
          broadcastStatus: broadcast_status,
          part: "snippet,status,contentDetails"
        },
        plug: params[:plug]
      ]

      case Client.request(:post, "/liveBroadcasts/transition", opts) do
        {:ok, response} -> {:ok, LiveStream.normalize_broadcast(response)}
        {:error, error} -> {:error, error}
      end
    end
  end

  defp required(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
