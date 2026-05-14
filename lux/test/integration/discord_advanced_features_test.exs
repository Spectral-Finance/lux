defmodule Lux.Integration.DiscordAdvancedFeaturesTest do
  use IntegrationCase, async: true

  alias Lux.Integrations.Discord.AdvancedFeatures

  test "builds an end-to-end advanced Discord workflow without opening live connections" do
    assert {:ok, plan} =
             AdvancedFeatures.advanced_feature_plan(%{
               voice: %{
                 action: :join,
                 guild_id: "111111111111111111",
                 channel_id: "222222222222222222",
                 queue: ["https://example.test/song.opus"]
               },
               presence: %{
                 status: :dnd,
                 activities: [%{type: :listening, name: "voice channel"}]
               },
               webhook: %{
                 action: :execute,
                 webhook_id: "333333333333333333",
                 token: "token",
                 content: "Voice session started"
               },
               events: [
                 %{type: :message, subtype: :command, user_id: "u1", channel_id: "commands"},
                 %{type: :voice, user_id: "u1", channel_id: "voice", duration_seconds: 60}
               ],
               analytics: %{
                 guild_id: "111111111111111111",
                 members: [%{id: "u1", bot: false, roles: ["member"]}]
               }
             })

    assert plan.ready
    assert plan.voice.safety.no_live_connection_opened
    assert plan.voice.queue.size == 1
    assert plan.rich_presence.status == "dnd"
    assert plan.webhook.request.method == :post
    assert plan.analytics.usage.audio_minutes == 1.0
  end
end
