defmodule Lux.Lenses.Discord.Messages.CreateMessage do
  @moduledoc """
  A lens for creating and sending messages to a Discord channel.
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Create Discord Message",
    description: "Sends a message to a Discord channel",
    url: "https://discord.com/api/v10/channels/:channel_id/messages",
    method: :post,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "Target Discord channel Snowflake ID",
          pattern: "^[0-9]{17,20}$"
        },
        content: %{
          type: :string,
          description: "Message body content (up to 2000 characters)",
          maxLength: 2000
        },
        tts: %{
          type: :boolean,
          description: "Whether this is a TTS message"
        },
        embeds: %{
          type: :array,
          description: "Embedded rich content"
        }
      },
      required: ["channel_id", "content"]
    }

  @impl true
  def before_focus(params) do
    payload = %{"content" => params.content}

    payload =
      if Map.get(params, :tts) != nil do
        Map.put(payload, "tts", params.tts)
      else
        payload
      end

    payload =
      if Map.get(params, :embeds) do
        Map.put(payload, "embeds", params.embeds)
      else
        payload
      end

    {:ok, payload}
  end

  @impl true
  def after_focus(response) when is_map(response) do
    {:ok,
     %{
       id: response["id"],
       channel_id: response["channel_id"],
       content: response["content"],
       author: response["author"],
       timestamp: response["timestamp"]
     }}
  end

  def after_focus(other), do: {:ok, other}
end
