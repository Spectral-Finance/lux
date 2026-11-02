defmodule Lux.Lenses.Discord.Messages.EditMessage do
  @moduledoc """
  A lens for editing previously sent messages in a Discord channel.
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Edit Discord Message",
    description: "Edits a previously sent message in a Discord channel",
    url: "https://discord.com/api/v10/channels/:channel_id/messages/:message_id",
    method: :patch,
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
        message_id: %{
          type: :string,
          description: "Target Discord message Snowflake ID",
          pattern: "^[0-9]{17,20}$"
        },
        content: %{
          type: :string,
          description: "New message content",
          maxLength: 2000
        }
      },
      required: ["channel_id", "message_id", "content"]
    }

  @impl true
  def before_focus(params) do
    {:ok, %{"content" => params.content}}
  end

  @impl true
  def after_focus(response) when is_map(response) do
    {:ok,
     %{
       id: response["id"],
       channel_id: response["channel_id"],
       content: response["content"],
       edited_timestamp: response["edited_timestamp"]
     }}
  end

  def after_focus(other), do: {:ok, other}
end
