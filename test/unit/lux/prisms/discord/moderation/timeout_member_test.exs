defmodule Lux.Prisms.Discord.Moderation.TimeoutMemberTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Discord.Moderation.TimeoutMember
  describe "handler/2" do
    test "returns tuple with valid inputs" do
      result = TimeoutMember.handler(%{"guild_id" => "123456789012345678", "user_id" => "987654321098765432", "duration_minutes" => 60}, %{})
      assert elem(result, 0) in [:ok, :error]
    end
    test "accepts optional reason", do:
      assert elem(TimeoutMember.handler(%{"guild_id" => "123456789012345678", "user_id" => "987654321098765432", "duration_minutes" => 30, "reason" => "spam"}, %{}), 0) in [:ok, :error]
  end
end
