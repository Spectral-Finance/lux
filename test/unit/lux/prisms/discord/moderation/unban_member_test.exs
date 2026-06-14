defmodule Lux.Prisms.Discord.Moderation.UnbanMemberTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Discord.Moderation.UnbanMember
  describe "handler/2" do
    test "returns tuple" do
      result = UnbanMember.handler(%{"guild_id" => "123456789012345678", "user_id" => "987654321098765432"}, %{})
      assert elem(result, 0) in [:ok, :error]
    end
  end
end
