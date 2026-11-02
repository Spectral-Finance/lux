defmodule Lux.Prisms.Discord.Messages.PinMessage do
  @moduledoc """
  A prism for pinning a message to a Discord channel.
  """

  use Lux.Prism,
    name: "Pin Discord Message",
    description: "Pins a message in a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Channel snowflake ID"},
        message_id: %{type: :string, description: "Message snowflake ID"}
      },
      required: ["channel_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        pinned: %{type: :boolean}
      },
      required: ["pinned"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, message_id} <- validate_param(params, :message_id) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Agent"
      Logger.info("Agent #{agent_name} pinning Discord message #{message_id} in channel #{channel_id}")

      opts = %{}
      opts = if plug = params[:plug], do: Map.put(opts, :plug, plug), else: opts
      opts = if token = params[:token], do: Map.put(opts, :token, token), else: opts

      case Client.request(:put, "/channels/#{channel_id}/pins/#{message_id}", opts) do
        {:ok, _} ->
          {:ok, %{pinned: true}}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, val} when is_binary(val) and val != "" -> {:ok, val}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end
end
