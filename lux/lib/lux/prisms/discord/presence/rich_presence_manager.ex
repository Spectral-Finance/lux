defmodule Lux.Prisms.Discord.Presence.RichPresenceManager do
  @moduledoc """
  Prism for Discord Rich Presence & Custom Status Management (`Spectral-Finance/lux#56`).

  Supports:
  - Custom status updates (`online`, `idle`, `dnd`, `invisible`)
  - Activity integration framework (`playing`, `streaming`, `listening`, `watching`, `competing`)
  - Game status synchronization (`sync_game`)
  - Rich presence update handling with party metadata and timestamps (`update_rich_presence`)
  """

  use Lux.Prism,
    name: "Discord Rich Presence & Status Manager",
    description: "Manages agent custom status, activity integration, game sync, and rich presence payloads",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["set_status", "set_activity", "sync_game", "update_rich_presence", "get_presence"],
          description: "Rich presence action"
        },
        agent_id: %{type: :string, description: "Identifier of the Discord agent"},
        status: %{type: :string, enum: ["online", "idle", "dnd", "invisible"]},
        custom_text: %{type: :string, description: "Custom status text"},
        activity_type: %{type: :string, enum: ["playing", "streaming", "listening", "watching", "competing"]},
        activity_name: %{type: :string},
        stream_url: %{type: :string},
        game_title: %{type: :string},
        party_current: %{type: :integer},
        party_max: %{type: :integer},
        details: %{type: :string},
        state_text: %{type: :string}
      },
      required: ["action", "agent_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        agent_id: %{type: :string},
        presence: %{type: :object}
      },
      required: ["agent_id", "presence"]
    }

  @table :lux_discord_presence_state

  @activity_type_codes %{
    "playing" => 0,
    "streaming" => 1,
    "listening" => 2,
    "watching" => 3,
    "competing" => 5
  }

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
      _ -> @table
    end
  end

  @impl true
  def handler(%{action: "set_status", agent_id: agent_id} = params, _ctx) do
    ensure_table()
    status = Map.get(params, :status, "online")

    if status not in ["online", "idle", "dnd", "invisible"] do
      {:error, :invalid_status}
    else
      current = get_presence(agent_id)
      updated = Map.merge(current, %{
        status: status,
        custom_text: Map.get(params, :custom_text),
        updated_at: System.system_time(:second)
      })
      :ets.insert(@table, {agent_id, updated})
      {:ok, %{agent_id: agent_id, presence: updated}}
    end
  end

  def handler(%{action: "set_activity", agent_id: agent_id} = params, _ctx) do
    ensure_table()
    act_type = Map.get(params, :activity_type, "playing")
    type_code = Map.get(@activity_type_codes, act_type, 0)
    current = get_presence(agent_id)

    activity = %{
      name: Map.get(params, :activity_name, "Lux Agent Runtime"),
      type: type_code,
      type_label: act_type,
      url: Map.get(params, :stream_url)
    }

    updated = Map.merge(current, %{activity: activity, updated_at: System.system_time(:second)})
    :ets.insert(@table, {agent_id, updated})
    {:ok, %{agent_id: agent_id, presence: updated}}
  end

  def handler(%{action: "sync_game", agent_id: agent_id} = params, _ctx) do
    ensure_table()
    current = get_presence(agent_id)
    game = %{
      title: Map.get(params, :game_title, "Autonomous Arena"),
      synchronized: true,
      session_started_at: System.system_time(:second)
    }
    updated = Map.merge(current, %{game: game, updated_at: System.system_time(:second)})
    :ets.insert(@table, {agent_id, updated})
    {:ok, %{agent_id: agent_id, presence: updated}}
  end

  def handler(%{action: "update_rich_presence", agent_id: agent_id} = params, _ctx) do
    ensure_table()
    current = get_presence(agent_id)
    rich_presence = %{
      details: Map.get(params, :details, "Executing Lux Beam"),
      state: Map.get(params, :state_text, "In Party"),
      party: %{
        current: Map.get(params, :party_current, 1),
        max: Map.get(params, :party_max, 4)
      },
      timestamps: %{start: System.system_time(:second)}
    }
    updated = Map.merge(current, %{rich_presence: rich_presence, updated_at: System.system_time(:second)})
    :ets.insert(@table, {agent_id, updated})
    {:ok, %{agent_id: agent_id, presence: updated}}
  end

  def handler(%{action: "get_presence", agent_id: agent_id}, _ctx) do
    ensure_table()
    {:ok, %{agent_id: agent_id, presence: get_presence(agent_id)}}
  end

  def handler(_params, _ctx), do: {:error, :invalid_presence_action}

  defp get_presence(agent_id) do
    case :ets.lookup(@table, agent_id) do
      [{^agent_id, p}] -> p
      [] -> %{status: "online", custom_text: nil, activity: nil, game: nil, rich_presence: nil}
    end
  end
end
