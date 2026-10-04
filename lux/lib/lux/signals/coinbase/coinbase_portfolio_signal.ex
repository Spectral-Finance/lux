defmodule Lux.Signals.Coinbase.PortfolioSignal do
  @moduledoc """
  Signal emitted upon portfolio balance synchronization, mark-to-market updates, or risk evaluation.
  """
  use Lux.Signal,
    schema_id: Lux.Schemas.Coinbase.PortfolioSchema
end
