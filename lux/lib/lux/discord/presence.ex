defmodule Lux.Discord.Presence do
  @moduledoc """
  Discord Rich Presence framework for Lux agents.

  Manages custom status text, activity states (Playing, Streaming, Listening, Watching, Competing),
  game status synchronization, and gateway presence payloads.
  """

  @type status_type :: :online | :dnd | :idle | :invisible
  @type activity_type :: :game | :streaming | :listening | :watching | :custom | :competing

  # Discord Gateway Activity Type IDs
  @activity_type_ids %{
    game: 0,
    streaming: 1,
    listening: 2,
    watching: 3,
    custom: 4,
    competing: 5
  }

  @doc """
  Updates the bot status and activity state.
  """
  @spec update_presence(keyword() | map()) :: {:ok, map()}
  def update_presence(opts) do
    status = get_opt(opts, :status, :online)
    activity_name = get_opt(opts, :activity_name, "Lux Autonomous Framework")
    activity_type = get_opt(opts, :activity_type, :game)
    details = get_opt(opts, :details, nil)
    state = get_opt(opts, :state, nil)

    type_id = Map.get(@activity_type_ids, activity_type, 0)

    payload = %{
      status: status,
      activities: [
        %{
          name: activity_name,
          type: type_id,
          details: details,
          state: state,
          created_at: System.system_time(:millisecond)
        }
      ],
      afk: status == :idle
    }

    Process.put(:lux_discord_presence_state, payload)
    {:ok, payload}
  end

  @doc """
  Synchronizes a game or simulation status.
  """
  @spec sync_game_status(String.t(), String.t() | nil, String.t() | nil) :: {:ok, map()}
  def sync_game_status(game_title, details \\ nil, state \\ nil) do
    update_presence(%{
      status: :online,
      activity_name: game_title,
      activity_type: :game,
      details: details,
      state: state
    })
  end

  @doc """
  Sets custom status message with optional emoji.
  """
  @spec set_custom_status(String.t(), String.t() | nil) :: {:ok, map()}
  def set_custom_status(text, emoji \\ nil) do
    payload = %{
      status: :online,
      activities: [
        %{
          name: "Custom Status",
          type: @activity_type_ids.custom,
          state: text,
          emoji: emoji,
          created_at: System.system_time(:millisecond)
        }
      ],
      afk: false
    }

    Process.put(:lux_discord_presence_state, payload)
    {:ok, payload}
  end

  @doc """
  Gets current presence payload.
  """
  @spec get_presence() :: map()
  def get_presence do
    Process.get(
      :lux_discord_presence_state,
      %{
        status: :online,
        activities: [%{name: "Lux Autonomous Agent", type: 0}],
        afk: false
      }
    )
  end

  defp get_opt(opts, key, default) when is_map(opts) do
    Map.get(opts, key) || Map.get(opts, to_string(key), default)
  end

  defp get_opt(opts, key, default) when is_list(opts) do
    Keyword.get(opts, key, default)
  end
end
