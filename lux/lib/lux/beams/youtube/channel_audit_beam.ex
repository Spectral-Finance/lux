defmodule Lux.Beams.Youtube.ChannelAuditBeam do
  @moduledoc """
  Beam for auditing YouTube channel data.
  """

  import Enum
import Jason
alias Lux.{Client, Error}

  defstruct [:channel_id, :metrics]

  def audit(channel_id) do
    %__MODULE__{channel_id: channel_id}
  end

  defp handle_response({:ok, %{"items" => items}}) do
    {:ok, Enum.map(items, fn item -> Map.take(item, ["id", "metrics"]) end)}
  end

  defp handle_response({:error, error}) do
    {:error, Error.new("Failed to audit channel data", error)}
  end
end

def initialize(channel_id) do
  %__MODULE__{channel_id: channel_id}
end