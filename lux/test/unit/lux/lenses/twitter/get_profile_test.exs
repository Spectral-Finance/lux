defmodule Lux.Lenses.Twitter.GetProfileTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Twitter.GetProfile

  describe "spec/0" do
    test "returns the correct specification" do
      spec = GetProfile.view()
      assert spec.name == "Twitter Profile Reader"
      assert Map.has_key?(spec.schema.properties, :username)
      assert "username" in spec.schema.required
    end
  end

  describe "before_focus/1" do
    test "assigns user fields" do
      params = %{"username" => "twitter"}
      updated = GetProfile.before_focus(params)
      assert updated["user.fields"] == "created_at,description,public_metrics,profile_image_url"
    end
  end

  describe "after_focus/1" do
    test "unwraps data payload" do
      response = %{"data" => %{"id" => "123", "username" => "twitter"}}
      assert {:ok, %{"id" => "123", "username" => "twitter"}} = GetProfile.after_focus(response)
    end
  end
end
