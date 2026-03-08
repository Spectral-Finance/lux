defmodule Lux.Prisms.Telegram.ContentModeration do
  @moduledoc """
  Content moderation prism for Telegram groups.

  Provides spam detection, content filtering, and automated moderation actions.
  """

  use Lux.Prism,
    name: "Telegram Content Moderation",
    description: "Moderate content in Telegram groups: spam detection, content filtering, auto-actions",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string, enum: ["check_spam", "delete_message", "delete_messages", "check_content", "auto_moderate"]},
        chat_id: %{type: [:string, :integer]},
        message_id: %{type: :integer},
        message_ids: %{type: :array, items: %{type: :integer}},
        text: %{type: :string},
        rules: %{type: :object, description: "Moderation rules configuration"}
      },
      required: ["action"]
    },
    output_schema: %{
      type: :object,
      properties: %{result: %{type: [:boolean, :object]}, action: %{type: :string}}
    }

  alias Lux.Integrations.Telegram.Client

  @spam_patterns [
    ~r/earn \$?\d+.*(?:per|a) (?:day|hour|week)/i,
    ~r/(?:free|easy)\s+(?:money|crypto|bitcoin)/i,
    ~r/(?:click|visit)\s+(?:here|this|the)\s+link/i,
    ~r/t\.me\/\w+.*(?:join|free|earn)/i,
    ~r/(?:whatsapp|telegram)\s*[\+:]?\s*\d{8,}/i,
    ~r/(?:100%|guaranteed)\s+(?:profit|return|income)/i,
    ~r/(?:send|dm|message)\s+(?:me|us)\s+(?:for|to)\s+(?:more|details)/i
  ]

  @link_pattern ~r/https?:\/\/[^\s]+/i
  @excessive_caps_threshold 0.7
  @max_emojis 10

  @impl true
  def handler(params, _agent) do
    action = params["action"] || params[:action]

    case action do
      "check_spam" -> check_spam(params)
      "delete_message" -> delete_message(params)
      "delete_messages" -> delete_messages(params)
      "check_content" -> check_content(params)
      "auto_moderate" -> auto_moderate(params)
      _ -> {:error, "Unknown action: #{action}"}
    end
  end

  defp check_spam(params) do
    text = params["text"] || params[:text] || ""

    spam_matches = @spam_patterns
      |> Enum.filter(&Regex.match?(&1, text))
      |> length()

    has_links = Regex.match?(@link_pattern, text)
    link_count = length(Regex.scan(@link_pattern, text))

    # Excessive caps check
    alpha_chars = String.replace(text, ~r/[^a-zA-Z]/, "")
    upper_ratio = if String.length(alpha_chars) > 10 do
      String.replace(alpha_chars, ~r/[^A-Z]/, "") |> String.length() |> Kernel./(String.length(alpha_chars))
    else
      0.0
    end

    score = spam_matches * 30 + (if has_links && spam_matches > 0, do: 20, else: 0) +
      (if link_count > 3, do: 15, else: 0) +
      (if upper_ratio > @excessive_caps_threshold, do: 10, else: 0)

    is_spam = score >= 30

    {:ok, %{
      result: %{
        is_spam: is_spam,
        spam_score: min(score, 100),
        spam_patterns_matched: spam_matches,
        has_links: has_links,
        link_count: link_count,
        excessive_caps: upper_ratio > @excessive_caps_threshold
      },
      action: "check_spam"
    }}
  end

  defp check_content(params) do
    text = params["text"] || params[:text] || ""
    rules = params["rules"] || params[:rules] || %{}

    violations = []

    # Max length
    max_len = rules["max_length"] || rules[:max_length]
    violations = if max_len && String.length(text) > max_len, do: [:too_long | violations], else: violations

    # Forbidden words
    forbidden = rules["forbidden_words"] || rules[:forbidden_words] || []
    lower = String.downcase(text)
    found_words = Enum.filter(forbidden, &String.contains?(lower, String.downcase(&1)))
    violations = if length(found_words) > 0, do: [:forbidden_words | violations], else: violations

    # No links
    no_links = rules["no_links"] || rules[:no_links] || false
    violations = if no_links && Regex.match?(@link_pattern, text), do: [:contains_links | violations], else: violations

    {:ok, %{
      result: %{
        compliant: length(violations) == 0,
        violations: violations,
        forbidden_words_found: found_words
      },
      action: "check_content"
    }}
  end

  defp delete_message(params) do
    token = params["token"] || params[:token] || ""
    chat_id = params["chat_id"] || params[:chat_id]
    msg_id = params["message_id"] || params[:message_id]
    plug = params["plug"] || params[:plug]

    case Client.request(:post, "/deleteMessage", %{token: token, json: %{chat_id: chat_id, message_id: msg_id}, plug: plug}) do
      {:ok, _} -> {:ok, %{result: true, action: "delete_message"}}
      error -> error
    end
  end

  defp delete_messages(params) do
    token = params["token"] || params[:token] || ""
    chat_id = params["chat_id"] || params[:chat_id]
    msg_ids = params["message_ids"] || params[:message_ids] || []
    plug = params["plug"] || params[:plug]

    case Client.request(:post, "/deleteMessages", %{token: token, json: %{chat_id: chat_id, message_ids: msg_ids}, plug: plug}) do
      {:ok, _} -> {:ok, %{result: true, action: "delete_messages"}}
      error -> error
    end
  end

  defp auto_moderate(params) do
    text = params["text"] || params[:text] || ""
    rules = params["rules"] || params[:rules] || %{}

    # Run both spam and content checks
    {:ok, spam_result} = check_spam(params)
    {:ok, content_result} = check_content(params)

    actions = []
    actions = if spam_result.result.is_spam, do: [:delete_message, :warn_user | actions], else: actions
    actions = if !content_result.result.compliant, do: [:delete_message | actions], else: actions

    # Repeated offender check (would integrate with AdminLogger in production)
    severity = cond do
      spam_result.result.spam_score >= 80 -> :ban
      spam_result.result.spam_score >= 50 -> :restrict
      !content_result.result.compliant -> :warn
      true -> :none
    end

    {:ok, %{
      result: %{
        spam_check: spam_result.result,
        content_check: content_result.result,
        recommended_actions: Enum.uniq(actions),
        severity: severity,
        should_act: length(actions) > 0
      },
      action: "auto_moderate"
    }}
  end
end
