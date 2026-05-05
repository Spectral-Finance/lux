defmodule Lux.Prisms.YouTube.LiveBroadcasts.TransitionBroadcast do
  @moduledoc "Transitions a YouTube live broadcast through testing/live/complete states."

  use Lux.Prism,
    name: "Transition YouTube Live Broadcast",
    description: "Transitions a YouTube live broadcast lifecycle status",
    input_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "Live broadcast ID"},
        broadcast_status: %{type: :string, enum: ["testing", "live", "complete"]}
      },
      required: ["id", "broadcast_status"]
    }

  alias Lux.Integrations.YouTube.Client

  @valid_statuses ~w(complete live testing)

  def handler(params, _agent) do
    with {:ok, id} <- required(params, :id),
         {:ok, status} <- required(params, :broadcast_status),
         :ok <- validate_status(status),
         {:ok, response} <- Client.request(:post, "/liveBroadcasts/transition", %{
           params: %{id: id, broadcastStatus: status, part: "status"}
         }) do
      {:ok, normalize(response)}
    end
  end

  defp validate_status(status) when status in @valid_statuses, do: :ok

  defp validate_status(_),
    do: {:error, "Invalid broadcast_status. Expected one of: complete, live, testing"}

  defp normalize(response) do
    status = response["status"] || %{}
    %{id: response["id"], lifecycle_status: status["lifeCycleStatus"]}
  end

  defp required(params, key) do
    case Map.get(params, key) || Map.get(params, to_string(key)) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
