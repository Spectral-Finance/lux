defmodule Lux.Signals.Coinbase.TickerSignal do
  @moduledoc """
  Signal emitted upon receipt of Coinbase ticker updates or price snapshots.
  """
  use Lux.Signal,
    schema_id: Lux.Schemas.Coinbase.TickerSchema
end
