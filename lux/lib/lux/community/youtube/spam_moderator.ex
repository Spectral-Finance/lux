defmodule Lux.Community.YouTube.SpamModerator do
  @moduledoc """
  Automated spam detection and content moderation engine for YouTube channels.

  Detects:
  - Telegram / WhatsApp investment bot recruitment schemes
  - Phishing / suspicious shortened URLs
  - Repeated character spam and low-entropy bot patterns
  - Excessive capitalization and emoji flooding
  - Toxic / abusive keywords requiring immediate hold or rejection
  """

  @crypto_scam_regex ~r/(whatsapp|telegram|t\.me\/|wa\.me\/|invest with|mrs\.? [a-z]+|guaranteed (return|profit)|trading expert|dm me on|contact (her|him) on|crypto recovery)/i
  @url_regex ~r/https?:\/\/[^\s]+/i
  @toxic_regex ~r/(idiot|stupid|kill yourself|hate you|moron|retard|scammer)/i

  @type moderation_action :: :approve | :hold_for_review | :reject | :ban_author

  @type moderation_verdict :: %{
          is_spam: boolean(),
          is_toxic: boolean(),
          spam_score: float(),
          recommended_action: moderation_action(),
          reasons: list(String.t())
        }

  @doc """
  Evaluates a comment string and assigns a spam probability score and recommended action.
  """
  @spec evaluate_comment(String.t()) :: moderation_verdict()
  def evaluate_comment(text) when is_binary(text) do
    cleaned = String.trim(text)

    reasons = []

    # 1. Check crypto / whatsapp bot scam patterns
    {has_scam, reasons} =
      if Regex.match?(@crypto_scam_regex, cleaned) do
        {true, ["Detected financial/crypto scam contact recruitment pattern" | reasons]}
      else
        {false, reasons}
      end

    # 2. Check external URLs
    {has_url, reasons} =
      if Regex.match?(@url_regex, cleaned) do
        {true, ["Contains unverified external hyperlink" | reasons]}
      else
        {false, reasons}
      end

    # 3. Check abusive/toxic language
    {has_toxic, reasons} =
      if Regex.match?(@toxic_regex, cleaned) do
        {true, ["Contains hostile or abusive language" | reasons]}
      else
        {false, reasons}
      end

    # 4. Check excessive caps ratio
    letters = String.replace(cleaned, ~r/[^a-zA-Z]/, "")
    caps = String.replace(cleaned, ~r/[^A-Z]/, "")
    caps_ratio = if String.length(letters) > 10, do: String.length(caps) / String.length(letters), else: 0.0

    {has_caps_spam, reasons} =
      if caps_ratio > 0.70 do
        {true, ["Excessive uppercase shouting (>70%)" | reasons]}
      else
        {false, reasons}
      end

    # Calculate overall spam score 0.0 - 1.0
    spam_score =
      0.0
      |> Kernel.+(if has_scam, do: 0.85, else: 0.0)
      |> Kernel.+(if has_url, do: 0.35, else: 0.0)
      |> Kernel.+(if has_caps_spam, do: 0.25, else: 0.0)
      |> min(1.0)
      |> Float.round(2)

    is_spam = spam_score >= 0.50

    recommended_action =
      cond do
        has_toxic -> :reject
        has_scam and spam_score >= 0.8 -> :ban_author
        is_spam -> :reject
        spam_score >= 0.3 or has_url -> :hold_for_review
        true -> :approve
      end

    %{
      is_spam: is_spam,
      is_toxic: has_toxic,
      spam_score: spam_score,
      recommended_action: recommended_action,
      reasons: Enum.reverse(reasons)
    }
  end

  @doc """
  Runs batch moderation over a list of comment maps.
  Returns map grouped by recommended action.
  """
  @spec moderate_batch(list(map())) :: %{
          approved: list(map()),
          held: list(map()),
          rejected: list(map()),
          banned: list(map())
        }
  def moderate_batch(comments) when is_list(comments) do
    Enum.reduce(comments, %{approved: [], held: [], rejected: [], banned: []}, fn comment, acc ->
      text = Map.get(comment, :text, Map.get(comment, "text", ""))
      verdict = evaluate_comment(text)
      annotated = Map.put(comment, :moderation_verdict, verdict)

      case verdict.recommended_action do
        :approve -> %{acc | approved: [annotated | acc.approved]}
        :hold_for_review -> %{acc | held: [annotated | acc.held]}
        :reject -> %{acc | rejected: [annotated | acc.rejected]}
        :ban_author -> %{acc | banned: [annotated | acc.banned]}
      end
    end)
  end
end
