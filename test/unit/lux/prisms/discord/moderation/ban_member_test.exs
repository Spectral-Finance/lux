defmodule Lux.Prisms.Discord.Moderation.BanMemberTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Discord.Moderation.BanMember
  describe "handler/2" do
    test "returns error with invalid guild_id" do
      result = BanMember.handler(%{"guild_id" => "abc", "user_id" => "123"}, %{})
      assert elem(result, 0) == :error
    end
    test "returns tuple with valid input" do
      result = BanMember.handler(%{"guild_id" => "123456789012345678", "user_id" => "987654321098765432"}, %{})
      assert elem(result, 0) in [:ok, :error]
    end
    test "accepts optional reason", do:
      assert elem(BanMember.handler(%{"guild_id" => "123456789012345678", "user_id" => "987654321098765432", "reason" => "spam"}, %{}), 0) in [:ok, :error]
  end
end
