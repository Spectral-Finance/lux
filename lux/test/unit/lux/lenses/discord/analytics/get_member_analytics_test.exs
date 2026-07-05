defmodule Lux.Lenses.Discord.Analytics.GetMemberAnalyticsTest do
  use ExUnit.Case
  
  alias Lux.Lenses.Discord.Analytics.GetMemberAnalytics

  test "exists and has correct properties" do
    assert Lux.Lenses.Discord.Analytics.GetMemberAnalytics.name() != nil
    assert Lux.Lenses.Discord.Analytics.GetMemberAnalytics.description() != nil
  end
end
