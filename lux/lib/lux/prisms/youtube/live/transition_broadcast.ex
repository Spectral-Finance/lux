defmodule Lux.Prisms.YouTube.Live.TransitionBroadcast do
  @moduledoc """
  Transitions a YouTube live broadcast between testing, live, and complete states.
  """

  use Lux.Prism,
    name: "Transition YouTube Live Broadcast",
    description: "Transitions a YouTube live broadcast lifecycle state",
    input_schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{type: :string, description: "Broadcast ID"},
        status: %{
          type: :string,
          enum: ["testing", "live", "complete"],
          description: "Target broadcast lifecycle status"
        },
        token: %{type: :string, description: "Optional OAuth2 access token"}
      },
      required: ["broadcast_id", "status"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        transitioned: %{type: :boolean, description: "Whether the transition succeeded"},
        broadcast_id: %{type: :string, description: "Broadcast ID"},
        status: %{type: :string, description: "Target status"}
      },
      required: ["transitioned", "broadcast_id", "status"]
    }

  alias Lux.Integrations.YouTube.Client

  def handler(params, _agent) do
    with {:ok, broadcast_id} <- validate_string(params, :broadcast_id),
         {:ok, status} <- validate_status(params) do
      case Client.transition_live_broadcast(broadcast_id, status, request_opts(params)) do
        {:ok, _response} ->
          {:ok, %{transitioned: true, broadcast_id: broadcast_id, status: status}}

        {:error, error} ->
          {:error, "Failed to transition YouTube broadcast: #{inspect(error)}"}
      end
    end
  end

  defp validate_string(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_status(%{status: status}) when status in ["testing", "live", "complete"] do
    {:ok, status}
  end

  defp validate_status(_params), do: {:error, "Missing or invalid status"}

  defp request_opts(%{token: token}) when is_binary(token) and token != "", do: %{token: token}
  defp request_opts(_params), do: %{}
end
