defmodule Lux.Integrations.Telegram.GroupManagement.ContentModerator do
  @moduledoc """
  Automated content moderation and spam protection engine for Telegram groups.
  Detects banned words, unauthorized invite links, mass mentions, forward spam,
  and recommends or executes enforcement actions (warn, delete, mute, ban).
  """

  alias Lux.Integrations.Telegram.Client
  alias Lux.Integrations.Telegram.GroupManagement.MemberManager
  alias Lux.Integrations.Telegram.GroupManagement.PermissionManager

  @default_banned_words [
    "airdrop claim",
    "free crypto",
    "connect wallet to claim",
    "send eth to get",
    "seed phrase",
    "private key giveaway",
    "guaranteed 100x"
  ]

  @default_config %{
    banned_words: @default_banned_words,
    allow_telegram_links: false,
    allow_external_links: true,
    max_mentions: 5,
    allow_forwards: true,
    action_on_banned_word: :delete_and_warn,
    action_on_spam_link: :delete_and_mute,
    action_on_mass_mention: :delete_and_mute
  }

  @doc """
  Checks an incoming message payload against moderation rules.
  """
  @spec check_content(map(), map()) :: {:ok, map()}
  def check_content(message, custom_config \\ %{}) do
    config = Map.merge(@default_config, custom_config)
    text = get_text(message)

    cond do
      violation = check_banned_words(text, config.banned_words) ->
        {:ok,
         %{
           violation: :banned_word,
           matched_term: violation,
           recommended_action: config.action_on_banned_word,
           severity: :high
         }}

      check_unauthorized_links(text, config) ->
        {:ok,
         %{
           violation: :unauthorized_link,
           recommended_action: config.action_on_spam_link,
           severity: :medium
         }}

      count = check_mass_mentions(text, message, config.max_mentions) ->
        {:ok,
         %{
           violation: :mass_mention,
           mention_count: count,
           recommended_action: config.action_on_mass_mention,
           severity: :high
         }}

      not config.allow_forwards and is_forwarded?(message) ->
        {:ok,
         %{
           violation: :forward_spam,
           recommended_action: :delete,
           severity: :low
         }}

      true ->
        {:ok, %{violation: nil, recommended_action: :none, severity: :none}}
    end
  end

  @doc """
  Deletes an offending message from the chat.
  """
  @spec delete_message(integer() | String.t(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def delete_message(chat_id, message_id, opts \\ []) do
    payload = %{chat_id: chat_id, message_id: message_id}
    request_opts = %{json: payload} |> maybe_put_plug(opts[:plug])
    Client.request(:post, "/deleteMessage", request_opts)
  end

  @doc """
  Executes an enforcement action against a user or message.
  Supported actions: `:delete`, `:warn`, `:delete_and_warn`, `:delete_and_mute`, `:ban`.
  """
  @spec enforce_action(integer() | String.t(), integer(), integer(), atom(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def enforce_action(chat_id, message_id, user_id, action, opts \\ []) do
    mute_duration = Keyword.get(opts, :mute_duration_seconds, 3600)

    case action do
      :delete ->
        delete_message(chat_id, message_id, opts)

      :delete_and_warn ->
        with {:ok, _} <- delete_message(chat_id, message_id, opts) do
          {:ok, %{action: :delete_and_warn, chat_id: chat_id, user_id: user_id}}
        end

      :delete_and_mute ->
        with {:ok, _} <- delete_message(chat_id, message_id, opts),
             {:ok, read_only} <- PermissionManager.get_preset(:read_only) do
          until = System.system_time(:second) + mute_duration

          MemberManager.restrict_member(chat_id, user_id, read_only,
            until_date: until,
            plug: opts[:plug]
          )
        end

      :ban ->
        with {:ok, _} <- delete_message(chat_id, message_id, opts) do
          MemberManager.ban_member(chat_id, user_id,
            revoke_messages: true,
            plug: opts[:plug]
          )
        end

      :none ->
        {:ok, %{action: :none}}

      other ->
        {:error, {:unsupported_action, other}}
    end
  end

  # --- Internal Helpers ---

  defp get_text(msg) when is_map(msg) do
    Map.get(msg, :text) || Map.get(msg, "text") ||
      Map.get(msg, :caption) || Map.get(msg, "caption") || ""
  end

  defp get_text(_), do: ""

  defp check_banned_words(text, banned_list) do
    lower = String.downcase(text)
    Enum.find(banned_list, fn word -> String.contains?(lower, String.downcase(word)) end)
  end

  defp check_unauthorized_links(text, %{allow_telegram_links: false}) do
    lower = String.downcase(text)
    String.contains?(lower, ["t.me/", "telegram.me/"])
  end

  defp check_unauthorized_links(_, _), do: false

  defp check_mass_mentions(text, message, max_mentions) do
    entities = Map.get(message, :entities) || Map.get(message, "entities") || []

    mention_entities =
      Enum.count(entities, fn e ->
        type = Map.get(e, :type) || Map.get(e, "type")
        type in ["mention", "text_mention"]
      end)

    raw_mentions = length(Regex.scan(~r/@[a-zA-Z0-9_]{3,}/, text))
    count = max(mention_entities, raw_mentions)

    if count >= max_mentions, do: count, else: nil
  end

  defp is_forwarded?(msg) do
    Map.has_key?(msg, :forward_date) or Map.has_key?(msg, "forward_date") or
      Map.has_key?(msg, :forward_from) or Map.has_key?(msg, "forward_from")
  end

  defp maybe_put_plug(map, nil), do: map
  defp maybe_put_plug(map, plug), do: Map.put(map, :plug, plug)
end
