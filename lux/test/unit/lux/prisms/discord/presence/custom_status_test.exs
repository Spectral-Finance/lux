defmodule Lux.Prisms.Discord.Presence.CustomStatusTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.Discord.Presence.CustomStatus

  @agent_ctx %{agent: %{name: "TestAgent"}}

  describe "handler/2" do
    test "builds basic custom status" do
      {:ok, result} = CustomStatus.handler(%{text: "Building things"}, @agent_ctx)

      assert result.activity.name == "Custom Status"
      assert result.activity.type == 4
      assert result.activity.state == "Building things"
      refute Map.has_key?(result.activity, :emoji)
    end

    test "builds custom status with emoji name" do
      {:ok, result} = CustomStatus.handler(%{text: "Working", emoji_name: "rocket"}, @agent_ctx)

      assert result.activity.state == "Working"
      assert result.activity.emoji.name == "rocket"
    end

    test "builds custom status with custom emoji" do
      {:ok, result} = CustomStatus.handler(
        %{text: "Coding", emoji_name: "parrot", emoji_id: "123456"},
        @agent_ctx
      )

      assert result.activity.emoji.name == "parrot"
      assert result.activity.emoji.id == "123456"
    end

    test "returns error when text is missing" do
      {:error, "Missing text parameter"} = CustomStatus.handler(%{}, @agent_ctx)
    end

    test "returns error when text is empty" do
      {:error, "Text must be a non-empty string"} = CustomStatus.handler(%{text: ""}, @agent_ctx)
    end

    test "returns error when text is not a string" do
      {:error, "Text must be a non-empty string"} = CustomStatus.handler(%{text: 123}, @agent_ctx)
    end
  end
end
