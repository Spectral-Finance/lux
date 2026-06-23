defmodule Lux.Prisms.Discord.ModerationPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Discord.ModerationPrism

  describe "handler/2" do
    test "returns error for missing guild_id for timeout" do
      input = %{
        "action" => "timeout",
        "user_id" => "123",
        "duration_seconds" => 60
      }
      assert {:error, "guild_id, user_id, and duration_seconds are required for timeout"} = ModerationPrism.handler(input, nil)
    end

    test "returns error for missing user_id for kick" do
      input = %{
        "action" => "kick",
        "guild_id" => "123"
      }
      assert {:error, "guild_id and user_id are required for kick"} = ModerationPrism.handler(input, nil)
    end

    test "returns error for missing user_id for ban" do
      input = %{
        "action" => "ban",
        "guild_id" => "123"
      }
      assert {:error, "guild_id and user_id are required for ban"} = ModerationPrism.handler(input, nil)
    end
  end
end
