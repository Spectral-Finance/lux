defmodule Lux.Integrations.Twitter.Automation.AutoReplyManager do
  @moduledoc """
  Manages automated Twitter replies, conversation context tracking,
  intent/template matching, cooldowns per user, and anti-loop safety guards.
  """

  @default_cooldown_seconds 1800 # 30 minutes

  @default_templates %{
    greeting: "Hey @%{username}! Thanks for reaching out. How can we help you today?",
    docs: "Hello @%{username}! You can explore our complete documentation and guides here: https://docs.lux.xyz",
    support: "Hi @%{username}! For technical assistance, please join our official Discord or check our status page.",
    generic: "Thanks for sharing your thoughts @%{username}! Stay tuned for upcoming updates."
  }

  @doc """
  Determines whether an incoming tweet or mention qualifies for an automated reply.
  Enforces cooldowns, self-mention prevention, and blacklisted handles.
  """
  @spec should_reply?(map(), map(), map()) :: {:ok, boolean(), atom()}
  def should_reply?(tweet, cooldown_state, config \\ %{}) do
    bot_id = Map.get(config, :bot_id, "my_bot")
    author_id = get_in(tweet, [:author_id]) || get_in(tweet, ["author_id"])
    author_username = get_in(tweet, [:author, :username]) || get_in(tweet, ["author", "username"]) || ""
    text = Map.get(tweet, :text) || Map.get(tweet, "text") || ""
    cooldown = Map.get(config, :cooldown_seconds, @default_cooldown_seconds)
    blacklist = Map.get(config, :blacklisted_users, [])

    now = System.system_time(:second)
    last_replied = Map.get(cooldown_state, author_id, 0)

    cond do
      author_id == bot_id ->
        {:ok, false, :self_mention}

      String.downcase(author_username) in Enum.map(blacklist, &String.downcase/1) ->
        {:ok, false, :blacklisted_user}

      now - last_replied < cooldown ->
        {:ok, false, :in_cooldown}

      is_spam?(text) ->
        {:ok, false, :detected_as_spam}

      true ->
        {:ok, true, :eligible}
    end
  end

  @doc """
  Generates an automated response based on matched intent or templates.
  """
  @spec generate_reply(map(), map()) :: {:ok, String.t()}
  def generate_reply(tweet, custom_templates \\ %{}) do
    templates = Map.merge(@default_templates, custom_templates)
    text = String.downcase(Map.get(tweet, :text) || Map.get(tweet, "text") || "")
    username = get_in(tweet, [:author, :username]) || get_in(tweet, ["author", "username"]) || "there"

    template_key =
      cond do
        String.contains?(text, ["doc", "docs", "guide", "tutorial", "learn"]) ->
          :docs

        String.contains?(text, ["help", "support", "issue", "bug", "broken"]) ->
          :support

        String.contains?(text, ["hello", "hi", "hey", "gm", "good morning"]) ->
          :greeting

        true ->
          :generic
      end

    raw_template = Map.get(templates, template_key, @default_templates.generic)
    reply_text = String.replace(raw_template, "%{username}", username)

    {:ok, reply_text}
  end

  @doc """
  Updates the user cooldown tracking table.
  """
  @spec update_cooldown(map(), String.t() | integer()) :: map()
  def update_cooldown(state, user_id) do
    Map.put(state, user_id, System.system_time(:second))
  end

  defp is_spam?(text) do
    lower = String.downcase(text)
    String.contains?(lower, ["airdrop claim", "free crypto", "telegram.me", "t.me/+", "dm to claim"])
  end
end
