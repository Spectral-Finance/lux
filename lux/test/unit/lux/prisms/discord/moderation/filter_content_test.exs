defmodule Lux.Prisms.Discord.Moderation.FilterContentTest do
  @moduledoc """
  Test suite for FilterContent prism.
  """

  use UnitAPICase, async: true
  alias Lux.Prisms.Discord.Moderation.FilterContent

  @agent_ctx %{agent: %{name: "TestAgent"}}

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "handler/2" do
    test "flags content containing banned words" do
      assert {:ok, %{
        flagged: true,
        matches: ["badword"],
        original_content: "This message contains badword"
      }} = FilterContent.handler(
        %{
          content: "This message contains badword",
          banned_words: ["badword", "anotherbad"]
        },
        @agent_ctx
      )
    end

    test "allows clean content" do
      assert {:ok, %{
        flagged: false,
        matches: [],
        original_content: "This is a clean message"
      }} = FilterContent.handler(
        %{
          content: "This is a clean message",
          banned_words: ["badword", "anotherbad"]
        },
        @agent_ctx
      )
    end
  end
end