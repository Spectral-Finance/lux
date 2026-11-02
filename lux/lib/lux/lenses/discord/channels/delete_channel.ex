defmodule Lux.Lenses.Discord.Channels.DeleteChannel do
  @moduledoc """
  A lens for deleting a channel, or closing a private message/thread.
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Delete Discord Channel",
    description: "Deletes a channel, or closes a private message",
    url: "https://discord.com/api/v10/channels/:channel_id",
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
        }
      },
      required: ["channel_id"]
    }

  @impl true
  def after_focus(response) when is_map(response) do
    {:ok, %{id: response["id"], deleted: true}}
  end

  def after_focus(other), do: {:ok, other}
end
