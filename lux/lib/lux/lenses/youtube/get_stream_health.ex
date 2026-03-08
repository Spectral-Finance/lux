defmodule Lux.Lenses.YouTube.GetStreamHealth do
  @moduledoc "Monitor live stream health via YouTube Live Streaming API."

  alias Lux.Integrations.YouTube.Client

  def focus(params, _opts \\ []) do
    broadcast_id = params[:broadcast_id] || params["broadcast_id"]

    with {:ok, broadcast} <- get_broadcast(broadcast_id, params),
         {:ok, stream} <- get_stream(broadcast, params) do
      {:ok, %{
        broadcast_status: get_in(broadcast, ["status", "lifeCycleStatus"]),
        stream_status: get_in(stream, ["status", "streamStatus"]),
        health_status: get_in(stream, ["status", "healthStatus", "status"]),
        resolution: get_in(stream, ["cdn", "resolution"]),
        frame_rate: get_in(stream, ["cdn", "frameRate"]),
        ingestion_type: get_in(stream, ["cdn", "ingestionType"]),
        ingestion_address: get_in(stream, ["cdn", "ingestionInfo", "ingestionAddress"]),
        stream_name: get_in(stream, ["cdn", "ingestionInfo", "streamName"])
      }}
    end
  end

  defp get_broadcast(id, params) do
    Client.request(:get, "/liveBroadcasts", %{
      params: %{part: "status,contentDetails", id: id},
      auth_type: :oauth2, access_token: params[:access_token], plug: params[:plug]
    })
    |> case do
      {:ok, %{"items" => [item | _]}} -> {:ok, item}
      {:ok, %{"items" => []}} -> {:error, :broadcast_not_found}
      error -> error
    end
  end

  defp get_stream(broadcast, params) do
    stream_id = get_in(broadcast, ["contentDetails", "boundStreamId"])
    if stream_id do
      Client.request(:get, "/liveStreams", %{
        params: %{part: "cdn,status", id: stream_id},
        auth_type: :oauth2, access_token: params[:access_token], plug: params[:plug]
      })
      |> case do
        {:ok, %{"items" => [item | _]}} -> {:ok, item}
        {:ok, %{"items" => []}} -> {:error, :stream_not_found}
        error -> error
      end
    else
      {:ok, %{}}
    end
  end
end
