defmodule Lux.Signals.Telegram.TelegramMessageSignal do
  @moduledoc """
  Signal representing an incoming or processed Telegram message.
  """

  use Lux.Signal,
    schema_id: Lux.Schemas.Telegram.TelegramMessageSchema
end
