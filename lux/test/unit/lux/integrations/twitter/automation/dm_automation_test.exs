defmodule Lux.Integrations.Twitter.Automation.DMAutomationTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Twitter.Automation.DMAutomation

  describe "DMAutomation" do
    test "generates personalized welcome message" do
      user = %{username: "crypto_builder"}
      msg = DMAutomation.generate_welcome_message(user)
      assert String.contains?(msg, "@crypto_builder")
      assert String.contains?(msg, "following Lux")
    end

    test "handles opt-out commands like STOP or UNSUBSCRIBE" do
      dm = %{sender_id: "user_555", text: "STOP"}
      opted_out = MapSet.new()

      assert {:ok, res, new_opted_out} = DMAutomation.process_message(dm, opted_out)
      assert res.action == :reply
      assert res.reason == :opt_out_confirmed
      assert MapSet.member?(new_opted_out, "user_555")

      # Subsequent messages from this user are ignored
      dm2 = %{sender_id: "user_555", text: "hello"}
      assert {:ok, res2, _} = DMAutomation.process_message(dm2, new_opted_out)
      assert res2.action == :ignore
      assert res2.reason == :user_opted_out
    end

    test "matches FAQ keywords automatically" do
      dm = %{sender_id: "user_777", text: "Can you send me the docs?"}
      opted_out = MapSet.new()

      assert {:ok, res, _} = DMAutomation.process_message(dm, opted_out)
      assert res.action == :reply
      assert res.reason == :faq_match
      assert String.contains?(res.reply_text, "https://docs.lux.xyz")
    end
  end
end
