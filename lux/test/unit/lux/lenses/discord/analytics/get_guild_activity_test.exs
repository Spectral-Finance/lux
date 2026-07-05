defmodule Lux.Lenses.Discord.Analytics.GetGuildActivityTest do
  use ExUnit.Case
  
  alias Lux.Lenses.Discord.Analytics.GetGuildActivity

  test "exists and has correct properties" do
    assert Lux.Lenses.Discord.Analytics.GetGuildActivity.name() != nil
    assert Lux.Lenses.Discord.Analytics.GetGuildActivity.description() != nil
  end
end
