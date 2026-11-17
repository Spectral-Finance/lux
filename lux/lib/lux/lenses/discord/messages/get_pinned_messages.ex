defmodule Lux.Lenses.Discord.Messages.GetPinnedMessages do
  @moduledoc """
  A lens for fetching pinned messages from a Discord channel.

  ## Examples
      iex> GetPinnedMessages.focus(%{channel_id: "123456789"})
      {:ok, [
        %{
          id: "111111111111111111",
          content: "Important announcement",
          author: %{id: "222222222222222222", username: "Admin"}
        }
      ]}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Get Pinned Discord Messages",
    description: "Fetches all pinned messages from a Discord channel",
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
  Transforms the Discord API response into a simpler format.
  """
  @impl true
  def after_focus(messages) when is_list(messages) do
    {:ok, Enum.map(messages, fn msg ->
      %{
        id: msg["id"],
        content: msg["content"],
        author: %{
          id: msg["author"]["id"],
          username: msg["author"]["username"]
        }
      }
    end)}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
