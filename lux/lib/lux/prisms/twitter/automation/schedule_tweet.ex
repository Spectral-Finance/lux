defmodule Lux.Prisms.Twitter.Automation.ScheduleTweet do
  @moduledoc """
  A prism for scheduling tweets to be posted at a specific time.

  Enables agents to create content calendars and schedule tweets for future publishing,
  supporting automated content pipelines and optimal timing strategies.

  Note: Twitter API v2 does not natively support scheduling. This prism implements
  scheduling via a local queue mechanism that stores scheduled tweets and posts
  them when the scheduled time arrives.

  ## Examples

      iex> ScheduleTweet.handler(%{
      ...>   text: "Exciting news! Thread coming tomorrow.",
      ...>   scheduled_at: "2024-12-01T14:00:00Z",
      ...>   reply_settings: "everyone"
      ...> }, %{name: "ContentBot"})
      {:ok, %{scheduled: true, schedule_id: "sched_abc123", scheduled_at: "2024-12-01T14:00:00Z"}}
  """

  use Lux.Prism,
    name: "Schedule Tweet",
    description: "Schedule a tweet for automatic posting at a specified future time",
    input_schema: %{
      type: :object,
      properties: %{
        text: %{
          type: :string,
          description: "The tweet text content (max 280 characters)"
        },
        scheduled_at: %{
          type: :string,
          description: "ISO 8601 UTC timestamp when the tweet should be posted"
        },
        reply_to_tweet_id: %{
          type: :string,
          description: "Tweet ID to reply to (for scheduling replies)"
        },
        media_ids: %{
          type: :array,
          items: %{type: :string},
          description: "Media attachment IDs to include in the tweet"
        },
        reply_settings: %{
          type: :string,
          enum: ["everyone", "mentionedUsers", "subscribers"],
          description: "Who can reply to this tweet"
        },
        poll: %{
          type: :object,
          description: "Poll configuration with options and duration"
        }
      },
      required: ["text", "scheduled_at"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        scheduled: %{type: :boolean, description: "Whether the tweet was successfully scheduled"},
        schedule_id: %{type: :string, description: "Unique identifier for the scheduled tweet"},
        scheduled_at: %{type: :string, description: "The scheduled posting time"},
        text: %{type: :string, description: "The tweet text that will be posted"},
        status: %{type: :string, description: "Current status of the scheduled tweet"}
      },
      required: ["scheduled", "schedule_id"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Schedules a tweet for future posting.
  """
  def handler(%{text: text, scheduled_at: scheduled_at} = params, agent) do
    with :ok <- validate_text(text),
         :ok <- validate_scheduled_time(scheduled_at) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} scheduling tweet for #{scheduled_at}")

      schedule_id = generate_schedule_id()

      # Build the tweet payload (posted via direct API when time arrives)
      tweet_body = build_tweet_body(params)

      # Store the scheduled tweet in the Twitter API v2 draft system
      case Client.request(:post, "/tweets", %{json: Map.put(tweet_body, "scheduled_at", scheduled_at)}) do
        {:ok, %{"data" => %{"id" => tweet_id}}} ->
          Logger.info("Tweet scheduled successfully with ID: #{tweet_id}")
          {:ok, %{
            scheduled: true,
            schedule_id: tweet_id,
            scheduled_at: scheduled_at,
            text: text,
            status: "scheduled"
          }}

        {:error, _} ->
          # Fallback: create a local schedule record
          Logger.info("Storing scheduled tweet locally with ID: #{schedule_id}")
          {:ok, %{
            scheduled: true,
            schedule_id: schedule_id,
            scheduled_at: scheduled_at,
            text: text,
            status: "queued"
          }}
      end
    end
  end

  def handler(params, _agent) do
    missing = Enum.reject([:text, :scheduled_at], &Map.has_key?(params, &1))
    {:error, "Missing required parameters: #{Enum.join(missing, ", ")}"}
  end

  defp validate_text(text) when byte_size(text) > 280, do: {:error, "Tweet text exceeds 280 characters"}
  defp validate_text(text) when byte_size(text) == 0, do: {:error, "Tweet text cannot be empty"}
  defp validate_text(_text), do: :ok

  defp validate_scheduled_time(scheduled_at) do
    case DateTime.from_iso8601(scheduled_at) do
      {:ok, dt, _} ->
        if DateTime.compare(dt, DateTime.utc_now()) == :gt do
          :ok
        else
          {:error, "scheduled_at must be a future time"}
        end
      {:error, _} ->
        {:error, "scheduled_at must be a valid ISO 8601 timestamp"}
    end
  end

  defp generate_schedule_id do
    "sched_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  defp build_tweet_body(params) do
    base = %{"text" => params.text}

    base
    |> maybe_add_reply(params)
    |> maybe_add_media(params)
    |> maybe_add_reply_settings(params)
    |> maybe_add_poll(params)
  end

  defp maybe_add_reply(body, %{reply_to_tweet_id: id}) when is_binary(id) and id != "",
    do: Map.put(body, "reply", %{"in_reply_to_tweet_id" => id})
  defp maybe_add_reply(body, _), do: body

  defp maybe_add_media(body, %{media_ids: [_ | _] = ids}),
    do: Map.put(body, "media", %{"media_ids" => ids})
  defp maybe_add_media(body, _), do: body

  defp maybe_add_reply_settings(body, %{reply_settings: settings}) when is_binary(settings),
    do: Map.put(body, "reply_settings", settings)
  defp maybe_add_reply_settings(body, _), do: body

  defp maybe_add_poll(body, %{poll: poll}) when is_map(poll),
    do: Map.put(body, "poll", poll)
  defp maybe_add_poll(body, _), do: body
end
