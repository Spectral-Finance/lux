defmodule Lux.Signals.Discord.MessageSignal do
  @moduledoc """
  A Lux Signal encapsulating a Discord message event.
  """

  use Lux.Signal,
    schema_id: Lux.Schemas.Discord.MessageSignalSchema
end
