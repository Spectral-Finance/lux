defmodule Lux.Signals.Coinbase.OrderSignal do
  @moduledoc """
  Signal emitted upon creation, update, cancellation, or fill of a Coinbase order.
  """
  use Lux.Signal,
    schema_id: Lux.Schemas.Coinbase.OrderSchema
end
