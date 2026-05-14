defmodule Lux.Prisms.Discord.AdvancedFeaturesTest do
  use UnitCase, async: true

  alias Lux.Prisms.Discord.AdvancedFeatures

  @ctx %{agent: %{name: "DiscordAgent"}}

  test "dispatches voice planning" do
    assert {:ok, %{status: "success", result: result}} =
             AdvancedFeatures.handler(
               %{
                 action: "voice",
                 params: %{
                   action: :join,
                   guild_id: "111111111111111111",
                   channel_id: "222222222222222222"
                 }
               },
               @ctx
             )

    assert result.action == :join
    assert result.safety.requires_voice_state_update
  end

  test "dispatches combined advanced feature planning" do
    assert {:ok, %{status: "success", result: result}} =
             AdvancedFeatures.handler(
               %{
                 action: "advanced_plan",
                 params: %{
                   voice: %{action: :join, guild_id: "1", channel_id: "2"},
                   presence: %{status: :online, activities: [%{type: :watching, name: "alerts"}]},
                   webhook: %{action: :list, guild_id: "1"},
                   events: [%{type: :message, user_id: "u1", channel_id: "2"}],
                   analytics: %{guild_id: "1"}
                 }
               },
               @ctx
             )

    assert result.ready
    assert result.analytics.event_count == 1
  end

  test "rejects unsupported actions" do
    assert {:error, "Unsupported Discord advanced operation"} =
             AdvancedFeatures.handler(%{action: "unknown"}, @ctx)
  end
end
