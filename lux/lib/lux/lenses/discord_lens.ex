defmodule Lux.Lenses.Discord do
  @moduledoc """
  Lenses for transforming raw Discord API data into structured Lux formats.
  """

  defmodule Message do
    def view(raw_msg) do
      %{
        id: raw_msg.id,
        content: raw_msg.content,
        author_id: raw_msg.author.id,
        channel_id: raw_msg.channel_id,
        timestamp: raw_msg.timestamp,
        mentions: Enum.map(raw_msg.mentions, & &1.id)
      }
    end
  end

  defmodule User do
    def view(raw_user) do
      %{
        id: raw_user.id,
        username: raw_user.username,
        discriminator: raw_user.discriminator,
        is_bot: raw_user.bot || false
      }
    end
  end
end
