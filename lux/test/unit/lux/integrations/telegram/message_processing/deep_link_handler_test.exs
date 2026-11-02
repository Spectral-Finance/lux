defmodule Lux.Integrations.Telegram.MessageProcessing.DeepLinkHandlerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Telegram.MessageProcessing.DeepLinkHandler

  describe "DeepLinkHandler" do
    test "parses referral codes from /start" do
      assert {:ok, result} = DeepLinkHandler.parse("/start ref_agent_007")
      assert result.type == :referral
      assert result.code == "agent_007"
      assert result.raw_payload == "ref_agent_007"
    end

    test "parses authentication tokens" do
      assert {:ok, result} = DeepLinkHandler.parse("auth_sec_token_999")
      assert result.type == :auth
      assert result.token == "sec_token_999"
    end

    test "parses transaction hashes" do
      assert {:ok, result} = DeepLinkHandler.parse("/start tx_0xabc123")
      assert result.type == :transaction
      assert result.hash == "0xabc123"
    end

    test "parses key-value packed payloads" do
      assert {:ok, result} = DeepLinkHandler.parse("src_twitter__camp_q4__ref_88")
      assert result.type == :key_value
      assert result.pairs.src == "twitter"
      assert result.pairs.camp == "q4"
      assert result.pairs.ref == "88"
    end

    test "parses URL-safe base64 payloads" do
      encoded = Base.url_encode64("action=verify", padding: false)
      assert {:ok, result} = DeepLinkHandler.parse("b64_" <> encoded)
      assert result.type == :base64
      assert result.data == "action=verify"
    end

    test "enforces 64-character Telegram limit" do
      too_long = String.duplicate("a", 65)
      assert {:error, {:payload_too_long, 65}} = DeepLinkHandler.parse(too_long)
    end

    test "generates compliant deep link URLs" do
      assert {:ok, bot_url} = DeepLinkHandler.generate_link("@LuxAgentBot", "ref_123")
      assert bot_url == "https://t.me/LuxAgentBot?start=ref_123"

      assert {:ok, group_url} =
               DeepLinkHandler.generate_link("LuxAgentBot", "ref_123", type: :group)

      assert group_url == "https://t.me/LuxAgentBot?startgroup=ref_123"

      assert {:ok, app_url} =
               DeepLinkHandler.generate_link("LuxAgentBot", "ref_123",
                 type: :mini_app,
                 app_name: "earn"
               )

      assert app_url == "https://t.me/LuxAgentBot/earn?startapp=ref_123"
    end

    test "generates deep link from map" do
      assert {:ok, url} =
               DeepLinkHandler.generate_link("LuxBot", %{source: "web", campaign: "launch"})

      assert String.contains?(url, "source_web")
      assert String.contains?(url, "campaign_launch")
    end
  end
end
