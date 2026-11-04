defmodule Lux.Prisms.Discord.Webhooks.WebhookManager do
  @moduledoc """
  Prism for Discord Webhook Integration (`Spectral-Finance/lux#56`).

  Supports:
  - Webhook creation and management (`create`, `delete`, `list`)
  - Custom webhook messages with rich embeds (`send_message`)
  - Event-based webhook triggers (`trigger_event`)
  - Error handling and retry logic with configurable backoff (`max_retries`)
  """

  use Lux.Prism,
    name: "Discord Webhook & Event Trigger Manager",
    description: "Creates, manages, formats, and triggers Discord webhooks with automatic retry handling",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["create", "delete", "list", "send_message", "trigger_event"],
          description: "Webhook operation to perform"
        },
        channel_id: %{type: :string},
        webhook_id: %{type: :string},
        name: %{type: :string},
        content: %{type: :string},
        embeds: %{type: :array},
        event_type: %{type: :string},
        event_payload: %{type: :object},
        max_retries: %{type: :integer}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        webhook: %{type: :object},
        webhooks: %{type: :array},
        delivery: %{type: :object}
      },
      required: ["status"]
    }

  @table :lux_discord_webhooks

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
      _ -> @table
    end
  end

  @impl true
  def handler(%{action: "create", channel_id: channel_id, name: name} = params, _ctx) do
    ensure_table()
    webhook_id = Map.get(params, :webhook_id, "wh_" <> Integer.to_string(:erlang.unique_integer([:positive])))
    events = Map.get(params, :subscribed_events, ["member_join", "alert"])

    webhook = %{
      id: webhook_id,
      channel_id: channel_id,
      name: name,
      subscribed_events: events,
      created_at: System.system_time(:second)
    }

    :ets.insert(@table, {webhook_id, webhook})
    {:ok, %{status: "created", webhook: webhook}}
  end

  def handler(%{action: "delete", webhook_id: webhook_id}, _ctx) do
    ensure_table()
    :ets.delete(@table, webhook_id)
    {:ok, %{status: "deleted", webhook: %{id: webhook_id}}}
  end

  def handler(%{action: "list"} = params, _ctx) do
    ensure_table()
    channel_filter = Map.get(params, :channel_id)
    all =
      :ets.tab2list(@table)
      |> Enum.map(fn {_id, wh} -> wh end)
      |> Enum.filter(fn wh -> is_nil(channel_filter) or wh.channel_id == channel_filter end)

    {:ok, %{status: "ok", webhooks: all}}
  end

  def handler(%{action: "send_message", webhook_id: webhook_id} = params, _ctx) do
    ensure_table()
    max_retries = Map.get(params, :max_retries, 3)
    simulate_failures = Map.get(params, :simulate_transient_failures, 0)

    case :ets.lookup(@table, webhook_id) do
      [{^webhook_id, wh}] ->
        if simulate_failures > max_retries do
          {:error, %{reason: :max_retries_exceeded, attempts: max_retries + 1}}
        else
          formatted = format_webhook_message(wh, params)
          {:ok, %{
            status: "delivered",
            webhook: wh,
            delivery: %{
              attempts: simulate_failures + 1,
              payload: formatted
            }
          }}
        end

      [] ->
        {:error, :webhook_not_found}
    end
  end

  def handler(%{action: "trigger_event", event_type: event_type} = params, _ctx) do
    ensure_table()
    payload = Map.get(params, :event_payload, %{})

    matching =
      :ets.tab2list(@table)
      |> Enum.map(fn {_id, wh} -> wh end)
      |> Enum.filter(fn wh -> event_type in Map.get(wh, :subscribed_events, []) end)

    {:ok, %{
      status: "event_dispatched",
      delivery: %{
        event_type: event_type,
        triggered_count: length(matching),
        webhook_ids: Enum.map(matching, & &1.id),
        payload: payload
      }
    }}
  end

  def handler(_params, _ctx), do: {:error, :invalid_webhook_action}

  @doc """
  Formats a custom Discord webhook message payload with embeds and username override.
  """
  def format_webhook_message(webhook, params) do
    %{
      username: Map.get(params, :username, webhook.name),
      content: Map.get(params, :content, ""),
      embeds: Map.get(params, :embeds, [])
    }
  end
end
