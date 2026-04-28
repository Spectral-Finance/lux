defmodule Lux.Integrations.SmartContractEvents.Parser do
  @moduledoc "Custom event parsing and decoding"

  @doc "Decode a log entry into a structured event"
  def decode_log(log, filter) do
    %{
      address: log["address"],
      topics: log["topics"],
      data: log["data"],
      block_number: decode_hex(log["blockNumber"]),
      transaction_hash: log["transactionHash"],
      log_index: decode_hex(log["logIndex"]),
      timestamp: DateTime.utc_now()
    }
  end

  @doc "Apply filter to an event"
  def matches_filter?(event, filter) when filter == %{}, do: true
  def matches_filter?(event, filter) do
    Enum.all?(filter, fn {key, value} ->
      Map.get(event, key) == value
    end)
  end

  defp decode_hex("0x" <> hex), do: String.to_integer(hex, 16)
  defp decode_hex(_), do: 0
end
