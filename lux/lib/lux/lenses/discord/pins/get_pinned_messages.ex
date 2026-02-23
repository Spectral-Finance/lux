defmodule Lux.Lenses.Discord.Pins.GetPinnedMessages do
  @moduledoc """
  A lens for retrieving pinned messages from a Discord channel.

  ## Examples
      iex> GetPinnedMessages.focus(%{
      ...>   channel_id: "123456789012345678"
      ...> })
      {:ok, [
        %{
          id: "111111111111111111",
          content: "Important pinned message",
          channel_id: "123456789012345678",
          author_id: "987654321098765432"
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Get Discord Pinned Messages",
    description: "Retrieves all pinned messages in a Discord channel",
    url: "https://discord.com/api/v10/channels/:channel_id/pins",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to get pinned messages from",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id"]
    }

  @doc """
  Transforms the raw Discord API response into a structured list of pinned messages.
  """
  @impl true
  def after_focus(messages) when is_list(messages) do
    {:ok, Enum.map(messages, fn msg ->
      %{
        id: msg["id"],
        content: msg["content"],
        channel_id: msg["channel_id"],
        author_id: get_in(msg, ["author", "id"]),
        timestamp: msg["timestamp"]
      }
    end)}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
