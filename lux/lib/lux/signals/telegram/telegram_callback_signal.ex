defmodule Lux.Signals.Telegram.TelegramCallbackSignal do
  @moduledoc """
  Signal representing an incoming Telegram inline keyboard button callback action.
  """

  use Lux.Signal,
    schema_id: Lux.Schemas.Telegram.TelegramCallbackSchema
end
