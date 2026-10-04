defmodule Lux.Signals.Telegram.TelegramCommandSignal do
  @moduledoc """
  Signal representing a parsed Telegram bot command.
  """

  use Lux.Signal,
    schema_id: Lux.Schemas.Telegram.TelegramCommandSchema
end
