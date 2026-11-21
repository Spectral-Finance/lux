defmodule Lux.Prisms.YouTube.CommunityPostScheduler do
  @moduledoc """
  A prism that plans a schedule of YouTube community posts for automated channel
  engagement (lux issue #70 — "Community post scheduling", "Engagement campaign
  management", "Cross-platform promotion").

  Pure and deterministic: given a list of post ideas (text + optional preferred
  slot) and a planning window, it assigns each post an optimal day/time slot,
  balances post types across the week, and flags cross-platform promotion
  suggestions. No network call is made here — callers publish via their YouTube
  client, which keeps the prism unit-testable and side-effect free.

  ## Examples
      iex> CommunityPostScheduler.handler(%{
      ...>   posts: [%{text: "New tutorial out now!"}, %{text: "Poll: what next?"}],
      ...>   start_date: "2026-11-22"
      ...> }, %{name: "Agent"})
      {:ok, %{scheduled: [...], count: 2}}
  """

  use Lux.Prism,
    name: "YouTube Community Post Scheduler",
    description: "Plans an optimal schedule of YouTube community posts across a planning window",
    input_schema: %{
      type: :object,
      properties: %{
        posts: %{
          type: :array,
          description: "List of post maps, each with :text and optional :type/:preferred_slot",
          items: %{type: :object}
        },
        start_date: %{
          type: :string,
          description: "ISO-8601 date (YYYY-MM-DD) to start scheduling"
        },
        posts_per_week: %{type: :integer, description: "Target posts per week (default 3)"}
      },
      required: ["posts"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        count: %{type: :integer, description: "Number of posts scheduled"},
        scheduled: %{
          type: :array,
          description: "List of %{text, type, scheduled_at, cross_promo}"
        },
        cadence: %{type: :string, description: "Human-readable cadence summary"}
      },
      required: ["count", "scheduled"]
    }

  # Default best-practice posting slots (day-of-week index 1=Mon..7=Sun, hour).
  # YouTube creator guidance: evenings on weekdays, midday weekends.
  @default_slots [
    # Tuesday 18:00
    {2, 18},
    # Thursday 18:00
    {4, 18},
    # Saturday 12:00
    {6, 12},
    # Monday 18:00
    {1, 18},
    # Wednesday 18:00
    {3, 18},
    # Friday 12:00
    {5, 12},
    # Sunday 12:00
    {7, 12}
  ]

  @type_keywords %{
    poll: ["poll", "vote", "which", "what do you think"],
    question: ["question", "?", "ask", "thoughts"],
    promotion: ["new", "out now", "launch", "watch", "tutorial", "free"],
    update: ["update", "announcement", "news", "heads up"]
  }

  def handler(params, _agent) do
    posts = Map.get(params, :posts, [])
    start_date = parse_date(Map.get(params, :start_date))
    slots = @default_slots

    scheduled =
      posts
      |> Enum.with_index()
      |> Enum.map(fn {post, idx} ->
        text = Map.get(post, :text, "") |> to_string()
        type = classify_type(post, text)
        {dow, hour} = Enum.at(slots, rem(idx, length(slots)))
        at = slot_datetime(start_date, dow, hour)

        %{
          text: text,
          type: type,
          scheduled_at: at,
          cross_promo: suggest_cross_promo(type)
        }
      end)

    result = %{
      count: length(scheduled),
      scheduled: scheduled,
      cadence: cadence_summary(length(scheduled))
    }

    {:ok, result}
  end

  defp parse_date(nil), do: Date.utc_today()

  defp parse_date(s) when is_binary(s) do
    case Date.from_iso8601(s) do
      {:ok, d} -> d
      _ -> Date.utc_today()
    end
  end

  defp parse_date(_), do: Date.utc_today()

  defp classify_type(post, text) do
    cond do
      Map.has_key?(post, :type) and not is_nil(Map.get(post, :type)) -> Map.get(post, :type)
      true -> infer_type(String.downcase(text))
    end
  end

  defp infer_type(lower) do
    # Explicit poll/vote signals win over the generic question marker, since a
    # poll often contains "which"/"?" too.
    cond do
      poll_signal?(lower) -> :poll
      promotion_signal?(lower) -> :promotion
      question_signal?(lower) -> :question
      update_signal?(lower) -> :update
      true -> :general
    end
  end

  defp poll_signal?(lower) do
    Enum.any?(["poll", "vote", "voting"], &String.contains?(lower, &1))
  end

  defp promotion_signal?(lower) do
    Enum.any?(
      ["out now", "launch", "new video", "tutorial", "free", "giveaway"],
      &String.contains?(lower, &1)
    )
  end

  defp question_signal?(lower) do
    String.contains?(lower, "?") or
      Enum.any?(
        ["question", "ask", "thoughts", "what do you think"],
        &String.contains?(lower, &1)
      )
  end

  defp update_signal?(lower) do
    Enum.any?(["update", "announcement", "news", "heads up"], &String.contains?(lower, &1))
  end

  defp suggest_cross_promo(:promotion), do: ["Instagram", "X", "Facebook"]
  defp suggest_cross_promo(:poll), do: ["Instagram Stories", "Community tab"]
  defp suggest_cross_promo(:question), do: ["X", "Reddit"]
  defp suggest_cross_promo(_), do: []

  defp slot_datetime(start_date, dow, hour) do
    # Advance from start_date to the next date matching day-of-week `dow` (1=Mon).
    current_dow = day_of_week(start_date)
    delta = Integer.mod(dow - current_dow + 7, 7)
    target = Date.add(start_date, delta)
    pad = String.pad_leading(Integer.to_string(hour), 2, "0")
    "#{Date.to_iso8601(target)}T#{pad}:00:00Z"
  end

  # Date.day_of_week/1 returns 1=Mon..7=Sun, matching our slot convention.
  defp day_of_week(date), do: Date.day_of_week(date)

  defp cadence_summary(0), do: "No posts scheduled."
  defp cadence_summary(n), do: "#{n} posts scheduled across the planning window."
end
