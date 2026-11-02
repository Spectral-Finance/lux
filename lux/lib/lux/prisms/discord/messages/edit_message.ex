defmodule Lux.Prisms.Discord.Messages.EditMessage do
  @moduledoc """
  A prism for editing an existing Discord message.
  """

  use Lux.Prism,
    name: "Edit Discord Message",
    description: "Edits a message previously sent in a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{type: :string, description: "Channel snowflake ID"},
        message_id: %{type: :string, description: "Message snowflake ID"},
        content: %{type: :string, description: "Updated message text content"},
        embeds: %{type: :array, description: "Updated embeds", items: %{type: :object}},
        components: %{type: :array, description: "Updated components", items: %{type: :object}}
      },
      required: ["channel_id", "message_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        edited: %{type: :boolean}
      },
      required: ["edited"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, message_id} <- validate_param(params, :message_id) do
      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Agent"
      Logger.info("Agent #{agent_name} editing Discord message #{message_id} in channel #{channel_id}")

      body =
        params
        |> Map.take([:content, :embeds, :components])
        |> Enum.reject(fn {_, v} -> is_nil(v) end)
        |> Map.new()

      opts = %{json: body}
      opts = if plug = params[:plug], do: Map.put(opts, :plug, plug), else: opts
      opts = if token = params[:token], do: Map.put(opts, :token, token), else: opts

      case Client.request(:patch, "/channels/#{channel_id}/messages/#{message_id}", opts) do
        {:ok, _} ->
          {:ok, %{edited: true}}

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
