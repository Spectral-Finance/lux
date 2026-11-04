defmodule Lux.Signals.Discord.InteractionSignal do
  @moduledoc """
  A Lux Signal encapsulating a Discord interaction event.
  """

  use Lux.Signal,
    schema_id: Lux.Schemas.Discord.InteractionSignalSchema
end
