defmodule Lux.Integrations.Twitter.Automation.ContentCalendar do
  @moduledoc """
  Manages recurring content calendar time slots, topic themes, and automated schedule planning.
  Assigns draft posts to optimal time slots based on weekly cadence and content pillars.
  """

  @type slot_id :: String.t()
  @type day_of_week :: 1..7 # 1 = Monday, 7 = Sunday

  @type calendar_slot :: %{
          id: slot_id(),
          day_of_week: day_of_week(),
          time: Time.t(),
          topic: atom(),
          active: boolean()
        }

  @type calendar :: %{
          slots: list(calendar_slot()),
          timezone: String.t()
        }

  @doc """
  Creates a new content calendar with optional default recurring slots.
  """
  @spec new_calendar(keyword()) :: calendar()
  def new_calendar(opts \\ []) do
    timezone = Keyword.get(opts, :timezone, "Etc/UTC")
    %{slots: [], timezone: timezone}
  end

  @doc """
  Adds a recurring publishing slot to the content calendar.
  `day_of_week`: 1 (Mon) to 7 (Sun)
  `time_str`: "HH:MM" (e.g. "09:00", "14:30")
  `topic`: atom category (e.g. :market_update, :education, :product, :community)
  """
  @spec add_slot(calendar(), day_of_week(), String.t(), atom()) :: {:ok, calendar(), calendar_slot()} | {:error, term()}
  def add_slot(calendar, day_of_week, time_str, topic \\ :general) when day_of_week in 1..7 do
    case Time.from_iso8601("#{time_str}:00") do
      {:ok, time} ->
        id = "slot_d#{day_of_week}_#{String.replace(time_str, ":", "")}_#{topic}"

        slot = %{
          id: id,
          day_of_week: day_of_week,
          time: time,
          topic: topic,
          active: true
        }

        updated_slots = Enum.reject(calendar.slots, &(&1.id == id)) ++ [slot]
        {:ok, %{calendar | slots: updated_slots}, slot}

      {:error, reason} ->
        {:error, {:invalid_time, reason}}
    end
  end

  def add_slot(_calendar, _day, _time, _topic), do: {:error, :invalid_day_of_week}

  @doc """
  Deactivates or removes a recurring slot.
  """
  @spec remove_slot(calendar(), slot_id()) :: calendar()
  def remove_slot(calendar, slot_id) do
    %{calendar | slots: Enum.reject(calendar.slots, &(&1.id == slot_id))}
  end

  @doc """
  Computes upcoming concrete publishing timestamps for active slots starting from `from_date` for `days_ahead` (default 7 days).
  """
  @spec get_upcoming_slots(calendar(), Date.t(), pos_integer()) :: list(%{slot: calendar_slot(), timestamp: DateTime.t()})
  def get_upcoming_slots(calendar, from_date \\ Date.utc_today(), days_ahead \\ 7) do
    0..(days_ahead - 1)
    |> Enum.flat_map(fn offset ->
      current_date = Date.add(from_date, offset)
      current_dow = Date.day_of_week(current_date)

      calendar.slots
      |> Enum.filter(&(&1.active and &1.day_of_week == current_dow))
      |> Enum.map(fn slot ->
        {:ok, naive} = NaiveDateTime.new(current_date, slot.time)
        dt = DateTime.from_naive!(naive, "Etc/UTC")
        %{slot: slot, timestamp: dt}
      end)
    end)
    |> Enum.sort_by(&DateTime.to_unix(&1.timestamp))
  end

  @doc """
  Automates schedule planning: maps a list of draft posts (with optional preferred topic)
  onto upcoming open calendar slots.
  """
  @spec plan_schedule(calendar(), list(map()), Date.t()) :: list(map())
  def plan_schedule(calendar, drafts, start_date \\ Date.utc_today()) when is_list(drafts) do
    upcoming = get_upcoming_slots(calendar, start_date, 14)

    # Match drafts to slots
    {planned, _rem_slots} =
      Enum.reduce(drafts, {[], upcoming}, fn draft, {acc_planned, available_slots} ->
        topic = Map.get(draft, :topic, :general)

        # Look for matching topic slot first, or fallback to first available
        candidate =
          Enum.find(available_slots, fn s -> s.slot.topic == topic end) ||
            List.first(available_slots)

        case candidate do
          nil ->
            {acc_planned, available_slots}

          slot_info ->
            plan_item = %{
              text: draft.text,
              topic: draft[:topic] || slot_info.slot.topic,
              scheduled_at: slot_info.timestamp,
              slot_id: slot_info.slot.id,
              media_ids: Map.get(draft, :media_ids, [])
            }

            {acc_planned ++ [plan_item], List.delete(available_slots, slot_info)}
        end
      end)

    planned
  end
end
