defmodule Lux.Lenses.Discord.Messages.BulkDelete do
  @moduledoc """
  A lens for deleting multiple messages simultaneously in a Discord channel (2-100 messages).
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Bulk Delete Discord Messages",
    description: "Deletes multiple messages simultaneously in a Discord channel",
    url: "https://discord.com/api/v10/channels/:channel_id/messages/bulk-delete",
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
        messages: %{
          type: :array,
          items: %{type: :string},
          description: "List of 2 to 100 message IDs to delete",
          minItems: 2,
          maxItems: 100
        }
      },
      required: ["channel_id", "messages"]
    }

  @impl true
  def before_focus(params) do
    {:ok, %{"messages" => params.messages}}
  end

  @impl true
  def after_focus("") do
    {:ok, %{bulk_deleted: true}}
  end

  def after_focus(nil) do
    {:ok, %{bulk_deleted: true}}
  end

  def after_focus(other), do: {:ok, other}
end
