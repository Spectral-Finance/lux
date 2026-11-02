defmodule Lux.YouTube.LiveStreaming.MultiStreamController do
  @moduledoc """
  Coordinates multi-stream quality control, primary/backup stream failover,
  and ingestion bandwidth allocation.
  """

  @type stream_channel :: %{
          id: String.t(),
          role: :primary | :backup,
          status: :healthy | :degraded | :offline,
          bitrate_kbps: non_neg_integer()
        }

  @type controller_state :: %{
          active_stream: :primary | :backup,
          primary: stream_channel(),
          backup: stream_channel(),
          failover_occurred: boolean(),
          last_switch_timestamp: String.t() | nil
        }

  @doc """
  Initializes a primary and backup stream pair.
  """
  @spec init_controller(String.t(), String.t()) :: controller_state()
  def init_controller(primary_id, backup_id) do
    %{
      active_stream: :primary,
      primary: %{id: primary_id, role: :primary, status: :healthy, bitrate_kbps: 6000},
      backup: %{id: backup_id, role: :backup, status: :healthy, bitrate_kbps: 6000},
      failover_occurred: false,
      last_switch_timestamp: nil
    }
  end

  @doc """
  Evaluates stream conditions and triggers automated failover if primary stream fails.
  """
  @spec check_and_failover(controller_state(), map(), map()) :: controller_state()
  def check_and_failover(state, primary_telemetry, backup_telemetry) do
    p_bitrate = Map.get(primary_telemetry, :bitrate_kbps, 6000)
    b_bitrate = Map.get(backup_telemetry, :bitrate_kbps, 6000)

    p_status = if p_bitrate < 1000, do: :degraded, else: :healthy
    b_status = if b_bitrate < 1000, do: :degraded, else: :healthy

    new_primary = %{state.primary | status: p_status, bitrate_kbps: p_bitrate}
    new_backup = %{state.backup | status: b_status, bitrate_kbps: b_bitrate}

    if state.active_stream == :primary and p_status == :degraded and b_status == :healthy do
      %{
        state
        | active_stream: :backup,
          primary: new_primary,
          backup: new_backup,
          failover_occurred: true,
          last_switch_timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    else
      %{state | primary: new_primary, backup: new_backup}
    end
  end
end
