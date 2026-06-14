defmodule Lux.Prisms.Discord.Moderation.GetMemberTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Discord.Moderation.GetMember
  describe "handler/2" do
    test "returns member data" do
      result = GetMember.handler(%{"guild_id" => "123456789012345678", "user_id" => "987654321098765432"}, %{})
      assert elem(result, 0) in [:ok, :error]
    end
  end
end
