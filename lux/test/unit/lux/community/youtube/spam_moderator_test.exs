defmodule Lux.Community.YouTube.SpamModeratorTest do
  use ExUnit.Case, async: true

  alias Lux.Community.YouTube.SpamModerator

  describe "evaluate_comment/1" do
    test "detects financial / WhatsApp telegram bot recruitment scams" do
      scam = "Contact Mrs. Alice on WhatsApp +1234567 for guaranteed profit and crypto recovery!"
      verdict = SpamModerator.evaluate_comment(scam)

      assert verdict.is_spam == true
      assert verdict.spam_score >= 0.8
      assert verdict.recommended_action in [:reject, :ban_author]
      assert length(verdict.reasons) > 0
    end

    test "flags external unverified URLs for review" do
      url_comment = "Check my website https://sketchy-link.xyz/download for more info"
      verdict = SpamModerator.evaluate_comment(url_comment)

      assert verdict.recommended_action in [:hold_for_review, :reject]
    end

    test "flags toxic harassment for rejection" do
      toxic = "You are a complete idiot and moron"
      verdict = SpamModerator.evaluate_comment(toxic)

      assert verdict.is_toxic == true
      assert verdict.recommended_action == :reject
    end

    test "approves clean, legitimate viewer feedback" do
      clean = "Really enjoyed the breakdown of GenServer state machines. Looking forward to part 2!"
      verdict = SpamModerator.evaluate_comment(clean)

      assert verdict.is_spam == false
      assert verdict.is_toxic == false
      assert verdict.recommended_action == :approve
    end
  end

  describe "moderate_batch/1" do
    test "categorizes batch of comments into action groups" do
      batch = [
        %{id: "1", text: "Love this channel!"},
        %{id: "2", text: "Contact Mrs. Brenda on telegram t.me/scam"},
        %{id: "3", text: "You are a stupid idiot"}
      ]

      result = SpamModerator.moderate_batch(batch)
      assert length(result.approved) == 1
      assert length(result.rejected) + length(result.banned) == 2
    end
  end
end
