defmodule Lux.YouTube.ContentCreation.ContentRepurposerTest do
  use UnitCase, async: true

  alias Lux.YouTube.ContentCreation.ContentRepurposer

  describe "repurpose/2" do
    test "generates Shorts scripts, viral Twitter thread, and LinkedIn article" do
      result = ContentRepurposer.repurpose("Building Autonomous AI Agents")

      assert length(result.shorts_scripts) == 3
      assert length(result.twitter_thread) == 7
      assert is_binary(result.linkedin_post)
      assert is_binary(result.blog_summary_markdown)

      # Check Shorts structure
      short = List.first(result.shorts_scripts)
      assert is_binary(short.hook)
      assert is_binary(short.body)
      assert is_binary(short.cta)
      assert short.duration_seconds <= 60
    end
  end
end
