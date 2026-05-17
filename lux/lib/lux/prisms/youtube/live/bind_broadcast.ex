defmodule Lux.Prisms.YouTube.Live.BindBroadcast do
  @moduledoc """
  Binds a YouTube live broadcast to a live stream.
  """

  use Lux.Prism,
    name: "Bind YouTube Live Broadcast",
    description: "Binds a broadcast id to a live stream id",
    input_schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{type: :string, description: "YouTube live broadcast id"},
        stream_id: %{type: :string, description: "YouTube live stream id"}
      },
      required: ["broadcast_id", "stream_id"]
    }

  alias Lux.Integrations.YouTube.Client
  alias Lux.Integrations.YouTube.LiveStream

  def handler(params, _agent) do
    with {:ok, broadcast_id} <- required(params, :broadcast_id),
         {:ok, stream_id} <- required(params, :stream_id) do
      opts = [
        token: params[:token],
        params: %{
          id: broadcast_id,
          streamId: stream_id,
          part: "snippet,status,contentDetails"
        },
        plug: params[:plug]
      ]

      case Client.request(:post, "/liveBroadcasts/bind", opts) do
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
