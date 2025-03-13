defmodule Lux.Signals.DiscordMessage do
  @moduledoc """
  Signal for sending messages to Discord channels.
  """
  use Lux.Signal,
    schema_id: Lux.Schemas.Discord.OutgoingMessageSchema
end
