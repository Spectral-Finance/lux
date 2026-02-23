defmodule Lux.Prisms.Twitter.Automation.AutoReply do
  @moduledoc """
  A prism for automatically replying to tweets based on configurable rules.

  Enables agents to monitor mentions and conversations, then automatically
  reply based on keyword triggers, user segments, or custom rules.

  ## Examples

      iex> AutoReply.handler(%{
      ...>   tweet_id: "1234567890",
      ...>   reply_text: "Thanks for reaching out! We'll get back to you shortly.",
      ...>   author_id: "987654321"
      ...> }, %{name: "SupportBot"})
      {:ok, %{replied: true, reply_tweet_id: "...", replied_to_tweet_id: "1234567890"}}
  """

  use Lux.Prism,
    name: "Auto Reply to Tweet",
    description: "Automatically reply to a tweet based on engagement rules",
    input_schema: %{
      type: :object,
      properties: %{
        tweet_id: %{
          type: :string,
          description: "ID of the tweet to reply to"
        },
        reply_text: %{
          type: :string,
          description: "Text content of the reply (max 280 characters)"
        },
        author_id: %{
          type: :string,
          description: "Author ID of the original tweet (for logging/tracking)"
        },
        include_username: %{
          type: :boolean,
          description: "Whether to @mention the original author in the reply"
        },
        rule_triggered: %{
          type: :string,
          description: "Name of the engagement rule that triggered this reply"
        }
      },
      required: ["tweet_id", "reply_text"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        replied: %{type: :boolean, description: "Whether the reply was sent successfully"},
        reply_tweet_id: %{type: :string, description: "ID of the newly created reply tweet"},
        replied_to_tweet_id: %{type: :string, description: "ID of the original tweet"},
        rule_triggered: %{type: :string, description: "The rule that triggered this reply"}
      },
      required: ["replied", "replied_to_tweet_id"]
    }

  alias Lux.Integrations.Twitter.Client
  require Logger

  @doc """
  Sends an automatic reply to the specified tweet.
  """
  def handler(%{tweet_id: tweet_id, reply_text: reply_text} = params, agent) do
    with :ok <- validate_reply_text(reply_text) do
      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} auto-replying to tweet #{tweet_id}")

      tweet_body = %{
        "text" => reply_text,
        "reply" => %{"in_reply_to_tweet_id" => tweet_id}
      }

      case Client.request(:post, "/tweets", %{json: tweet_body}) do
        {:ok, %{"data" => %{"id" => reply_id, "text" => _text}}} ->
          Logger.info("Successfully replied to tweet #{tweet_id} with reply ID: #{reply_id}")
          {:ok, %{
            replied: true,
            reply_tweet_id: reply_id,
            replied_to_tweet_id: tweet_id,
            rule_triggered: Map.get(params, :rule_triggered)
          }}

        {:error, :rate_limited} ->
          {:error, "Rate limit exceeded — too many replies in a short period"}

        {:error, {status, message}} ->
          {:error, "Failed to reply: #{message} (HTTP #{status})"}

        {:error, error} ->
          {:error, "Failed to send reply: #{inspect(error)}"}
      end
    end
  end

  def handler(params, _agent) do
    missing = Enum.reject([:tweet_id, :reply_text], &Map.has_key?(params, &1))
    {:error, "Missing required parameters: #{Enum.join(missing, ", ")}"}
  end

  defp validate_reply_text(text) when byte_size(text) > 280,
    do: {:error, "Reply text exceeds 280 characters"}
  defp validate_reply_text(text) when byte_size(text) == 0,
    do: {:error, "Reply text cannot be empty"}
  defp validate_reply_text(_text), do: :ok
end
