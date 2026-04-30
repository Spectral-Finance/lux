defmodule Lux.Lenses.Youtube.VideoInfoLensTest do
  use ExUnit.Case, async: true
  doctest Lux.Lenses.Youtube.VideoInfoLens

  describe "focus/1" do
    test "returns error for missing video_id" do
      assert {:error, _} = Lux.Lenses.Youtube.VideoInfoLens.focus(%{})
    end

    test "has correct lens metadata" do
      assert Lux.Lenses.Youtube.VideoInfoLens.__meta__(:name) == "YouTube Video Info"
      assert Lux.Lenses.Youtube.VideoInfoLens.__meta__(:method) == :get
    end

    test "schema has required fields" do
      schema = Lux.Lenses.Youtube.VideoInfoLens.__schema__()
      assert schema[:properties][:video_id] != nil
      assert "video_id" in schema[:required]
    end

    test "output schema defines all expected fields" do
      output = Lux.Lenses.Youtube.VideoInfoLens.__output_schema__()
      assert output[:properties][:title] != nil
      assert output[:properties][:view_count] != nil
      assert output[:properties][:like_count] != nil
      assert output[:properties][:comment_count] != nil
      assert output[:properties][:duration] != nil
      assert output[:properties][:tags] != nil
    end
  end
end
