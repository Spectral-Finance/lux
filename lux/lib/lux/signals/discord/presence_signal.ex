defmodule Lux.Signals.Discord.PresenceSignal do
  @moduledoc """
  A Lux Signal encapsulating a Discord presence update event.
  """

  use Lux.Signal,
    schema_id: Lux.Schemas.Discord.PresenceSignalSchema
end
