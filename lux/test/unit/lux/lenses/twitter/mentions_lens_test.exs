defmodule Lux.Lenses.Twitter.MentionsLensTest do
  use UnitAPICase, async: true

  alias Lux.Lenses.Twitter.MentionsLens

  setup do
    Req.Test.verify_on_exit!()
    :ok
  end

  describe "after_focus/1" do
    test "correctly parses mentions from API response" do
      response = {:ok, %{
        "data" => [
          %{"id" => "1", "text" => "hello @bot", "author_id" => "101"},
          %{"id" => "2", "text" => "how are you @bot", "author_id" => "102"}
        ],
        "meta" => %{"result_count" => 2}
      }}

      assert {:ok, mentions} = MentionsLens.after_focus(response)
      assert length(mentions) == 2
      assert Enum.at(mentions, 0) == %{id: "1", text: "hello @bot", author_id: "101"}
    end

    test "handles empty results" do
      response = {:ok, %{"meta" => %{"result_count" => 0}}}
      assert {:ok, []} = MentionsLens.after_focus(response)
    end
  end
end
