defmodule Lux.Lenses.Discord.Messages.DeleteMessage do
  @moduledoc """
  A lens for deleting a message from a Discord channel.
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Delete Discord Message",
    description: "Deletes a message from a Discord channel",
    url: "https://discord.com/api/v10/channels/:channel_id/messages/:message_id",
    method: :delete,
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
        }
      },
      required: ["channel_id", "message_id"]
    }

  @impl true
  def after_focus("") do
    {:ok, %{deleted: true}}
  end

  def after_focus(nil) do
    {:ok, %{deleted: true}}
  end

  def after_focus(other), do: {:ok, other}
end
