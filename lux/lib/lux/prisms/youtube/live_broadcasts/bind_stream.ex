defmodule Lux.Prisms.YouTube.LiveBroadcasts.BindStream do
  @moduledoc "Binds a YouTube live stream to a live broadcast."

  use Lux.Prism,
    name: "Bind YouTube Live Stream",
    description: "Binds an existing live stream to a broadcast",
    input_schema: %{
      type: :object,
      properties: %{id: %{type: :string}, stream_id: %{type: :string}},
      required: ["id", "stream_id"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _agent) do
    with {:ok, id} <- required(params, :id),
         {:ok, stream_id} <- required(params, :stream_id),
         {:ok, response} <- Client.request(:post, "/liveBroadcasts/bind", %{
           params: %{id: id, streamId: stream_id, part: "id,contentDetails"}
         }) do
      details = response["contentDetails"] || %{}
      {:ok, %{id: response["id"], bound_stream_id: details["boundStreamId"]}}
    end
  end

  defp required(params, key) do
    case Map.get(params, key) || Map.get(params, to_string(key)) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
