defmodule Lux.Lenses.Twitter.ProfileLensTest do
  use ExUnit.Case, async: true
  alias Lux.Lenses.Twitter.ProfileLens
  alias Lux.Lens.Twitter.Profile

  test "returns Profile struct on success" do
    response = %{
      "data" => %{
        "id" => "12345",
        "name" => "Lux Agent",
        "username" => "lux_agent",
        "description" => "I am a bot",
        "profile_image_url" => "https://example.com/image.png"
      }
    }

    assert {:ok, %Profile{} = profile} = ProfileLens.after_focus(response)
    assert profile.id == "12345"
    assert profile.username == "lux_agent"
    assert profile.name == "Lux Agent"
    assert profile.description == "I am a bot"
    assert profile.profile_image_url == "https://example.com/image.png"
  end

  test "returns error on failure" do
    assert {:error, "Not Found"} = ProfileLens.after_focus(%{"errors" => [%{"detail" => "Not Found"}]})
  end
end
