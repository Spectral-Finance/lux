defmodule Lux.Prisms.Discord.Moderation.WarnMemberTest do
  @moduledoc """
  Test suite for WarnMember prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Moderation.WarnMember

  @guild_id "123456789012345678"
  @user_id "999999999999999999"
  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "successfully issues a warning" do
      # This test mocks the internal storage, no Discord API call
      assert {:ok, %{
        warned: true,
        guild_id: @guild_id,
        user_id: @user_id,
        warning_id: warning_id
      }} = WarnMember.handler(
        %{
          guild_id: @guild_id,
          user_id: @user_id,
          reason: "Spamming",
          moderator_id: "888888888888888888"
        },
        @agent_ctx
      ) when warning_id = "warn_" <> _

      assert String.starts_with?(warning_id, "warn_")
    end
  end
end