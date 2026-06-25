defmodule Lux.Integrations.Discord.WebhookEvents do
  @moduledoc """
  Event-based webhook trigger system for Discord.

  Provides a framework for defining triggers that automatically execute
  webhooks when matching events are received. Supports filtering, rate
  limiting, and custom message formatting.

  ## Usage

      trigger = WebhookEvents.new_trigger(
        name: "new-member-greeting",
        webhook_url: "https://discord.com/api/webhooks/...",
        filter: %{type: :member_join},
        format_fn: fn event ->
          %{content: "Welcome <@\#{event.user_id}>!"}
        end,
        rate_limit_ms: 5000
      )

      results = WebhookEvents.process([trigger], events, client_opts)

  ## Trigger Options

    * `:name` — Human-readable trigger name
    * `:webhook_url` — Full webhook URL for execution
    * `:filter` — Map of key-value pairs to match against events
    * `:format_fn` — Function that transforms events into webhook payloads
    * `:rate_limit_ms` — Minimum ms between executions per trigger (default: 0)

  """

  alias Lux.Integrations.Discord.Webhooks

  @type trigger :: %{
          name: String.t(),
          webhook_url: String.t(),
          filter: map(),
          format_fn: (map() -> map()),
          rate_limit_ms: non_neg_integer(),
          last_executed_at: DateTime.t() | nil
        }

  @type process_result :: %{
          executed: [map()],
          skipped: [%{trigger: String.t(), reason: atom()}],
          errors: [%{trigger: String.t(), error: term()}]
        }

  @doc """
  Creates a new webhook trigger.

  ## Examples

      iex> trigger = WebhookEvents.new_trigger(
      ...>   name: "alert",
      ...>   webhook_url: "https://discord.com/api/webhooks/123/token",
      ...>   filter: %{type: :message},
      ...>   format_fn: fn e -> %{content: e.metadata[:content]} end
      ...> )
      iex> trigger.name
      "alert"

  """
  @spec new_trigger(keyword()) :: trigger()
  def new_trigger(opts \\ []) do
    %{
      name: Keyword.get(opts, :name, "unnamed"),
      webhook_url: Keyword.fetch!(opts, :webhook_url),
      filter: Keyword.get(opts, :filter, %{}),
      format_fn: Keyword.get(opts, :format_fn, &default_format/1),
      rate_limit_ms: Keyword.get(opts, :rate_limit_ms, 0),
      last_executed_at: nil
    }
  end

  @doc """
  Processes a list of events against a list of triggers.

  Returns a result map with `:executed`, `:skipped`, and `:errors` lists.

  ## Examples

      results = WebhookEvents.process(triggers, events, plug: {Req.Test, Mock})

  """
  @spec process([trigger()], [map()], keyword() | map()) :: process_result()
  def process(triggers, events, opts \\ %{}) do
    Enum.reduce(events, %{executed: [], skipped: [], errors: []}, fn event, acc ->
      Enum.reduce(triggers, acc, fn trigger, inner_acc ->
        process_event(trigger, event, opts, inner_acc)
      end)
    end)
  end

  @doc """
  Checks whether an event matches a trigger's filter.

  Matches when all filter key-value pairs exist in the event map.
  Supports both atom and string keys.

  ## Examples

      iex> WebhookEvents.matches?(%{type: :message, user_id: "u1"}, %{type: :message})
      true

      iex> WebhookEvents.matches?(%{type: :message}, %{type: :voice})
      false

  """
  @spec matches?(map(), map()) :: boolean()
  def matches?(event, filter) when map_size(filter) == 0, do: true

  def matches?(event, filter) do
    Enum.all?(filter, fn {key, expected_value} ->
      Map.get(event, key) == expected_value ||
        Map.get(event, to_string(key)) == expected_value
    end)
  end

  @doc """
  Checks whether a trigger is currently rate-limited.

  Returns `true` if the trigger should be suppressed (too soon since last execution).

  ## Examples

      iex> trigger = %{rate_limit_ms: 5000, last_executed_at: DateTime.utc_now()}
      iex> WebhookEvents.rate_limited?(trigger, DateTime.utc_now())
      true

  """
  @spec rate_limited?(trigger(), DateTime.t()) :: boolean()
  def rate_limited?(%{rate_limit_ms: 0}, _now), do: false
  def rate_limited?(%{last_executed_at: nil}, _now), do: false

  def rate_limited?(trigger, now) do
    diff_ms = DateTime.diff(now, trigger.last_executed_at, :millisecond)
    diff_ms < trigger.rate_limit_ms
  end

  # --- Private ---

  defp process_event(trigger, event, opts, acc) do
    now = DateTime.utc_now()

    cond do
      not matches?(event, trigger.filter) ->
        update_in(acc.skipped, fn s ->
          s ++ [%{trigger: trigger.name, reason: :no_match}]
        end)

      rate_limited?(trigger, now) ->
        update_in(acc.skipped, fn s ->
          s ++ [%{trigger: trigger.name, reason: :rate_limited}]
        end)

      true ->
        payload = trigger.format_fn.(event)

        case Webhooks.execute_webhook(trigger.webhook_url, payload, opts) do
          {:ok, result} ->
            updated_trigger = %{trigger | last_executed_at: now}

            acc
            |> update_in([:executed], fn e ->
              e ++ [%{trigger: trigger.name, result: result, event: event}]
            end)

          {:error, error} ->
            update_in(acc.errors, fn e ->
              e ++ [%{trigger: trigger.name, error: error}]
            end)
        end
    end
  end

  defp default_format(event) do
    content =
      event
      |> Map.get(:metadata, %{})
      |> Map.get(:content, inspect(event))

    %{content: content}
  end
end
