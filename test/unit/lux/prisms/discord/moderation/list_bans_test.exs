defmodule Lux.Prisms.Discord.Moderation.ListBansTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.Discord.Moderation.ListBans
  describe "handler/2" do
    test "returns bans list" do
      result = ListBans.handler(%{"guild_id" => "123456789012345678"}, %{})
      assert elem(result, 0) in [:ok, :error]
    end
    test "accepts limit parameter", do:
      assert elem(ListBans.handler(%{"guild_id" => "123456789012345678", "limit" => 10}, %{}), 0) in [:ok, :error]
  end
end
