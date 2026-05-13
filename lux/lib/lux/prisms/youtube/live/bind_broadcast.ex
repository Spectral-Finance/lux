defmodule Lux.Prisms.YouTube.Live.BindBroadcast do
  @moduledoc """
  Binds a YouTube live broadcast to a live stream resource.
  """

  use Lux.Prism,
    name: "Bind YouTube Live Broadcast",
    description: "Binds a YouTube live broadcast to a stream",
    input_schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{type: :string, description: "Broadcast ID"},
        stream_id: %{type: :string, description: "Stream ID"},
        token: %{type: :string, description: "Optional OAuth2 access token"}
      },
      required: ["broadcast_id", "stream_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        bound: %{type: :boolean, description: "Whether the bind request succeeded"},
        broadcast_id: %{type: :string, description: "Broadcast ID"},
        stream_id: %{type: :string, description: "Stream ID"}
      },
      required: ["bound", "broadcast_id", "stream_id"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _agent) do
    with {:ok, broadcast_id} <- validate_string(params, :broadcast_id),
         {:ok, stream_id} <- validate_string(params, :stream_id) do
      case Client.bind_live_broadcast(broadcast_id, stream_id, request_opts(params)) do
        {:ok, _response} ->
          {:ok, %{bound: true, broadcast_id: broadcast_id, stream_id: stream_id}}

        {:error, error} ->
          {:error, "Failed to bind YouTube broadcast: #{inspect(error)}"}
      end
    end
  end

  defp validate_string(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp request_opts(%{token: token}) when is_binary(token) and token != "", do: %{token: token}
  defp request_opts(_params), do: %{}
end
