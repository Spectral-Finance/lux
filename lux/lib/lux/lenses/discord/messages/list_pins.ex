defmodule Lux.Lenses.Discord.Messages.ListPins do
  @moduledoc """
  A lens for listing pinned messages from a Discord channel.

  This covers the read side of Discord pinned-message management so agents can
  inspect pinned context before pinning/unpinning or summarizing a channel.
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "List Discord Pinned Messages",
    description: "Lists pinned messages from a Discord channel",
    url: "https://discord.com/api/v10/channels/:channel_id/pins",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to list pinned messages from",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id"]
    }

  @doc """
  Transforms the Discord API response into a concise pinned-message list.
  """
  @impl true
  def after_focus(messages) when is_list(messages) do
    {:ok,
     Enum.map(messages, fn message ->
       %{
         id: message["id"],
         content: message["content"],
         pinned: message["pinned"],
         timestamp: message["timestamp"],
         author: extract_author(message["author"])
       }
     end)}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end

  defp extract_author(%{"id" => id, "username" => username}) do
    %{id: id, username: username}
  end

  defp extract_author(_), do: nil
end
