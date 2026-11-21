defmodule Lux.Prisms.YouTube.UtilTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.Util

  describe "tokenize/content_words" do
    test "tokenizes lowercase words" do
      assert Util.tokenize("Hello World 123") == ["hello", "world", "123"]
    end

    test "drops stopwords and short words" do
      words = Util.content_words("the a cat elixir is great")
      refute "the" in words
      refute "is" in words
      assert "elixir" in words
      assert "great" in words
    end
  end

  describe "safe_div" do
    test "returns 0.0 on zero denominator" do
      assert Util.safe_div(10, 0) == 0.0
    end

    test "divides normally" do
      assert Util.safe_div(10, 4) == 2.5
    end
  end

  describe "parse_iso8601_duration" do
    test "parses PT1H2M3S" do
      assert Util.parse_iso8601_duration("PT1H2M3S") == 3723.0
    end

    test "parses PT45S" do
      assert Util.parse_iso8601_duration("PT45S") == 45.0
    end

    test "parses P1DT2H" do
      assert Util.parse_iso8601_duration("P1DT2H") == 93_600.0
    end

    test "returns 0.0 for invalid" do
      assert Util.parse_iso8601_duration("") == 0.0
      assert Util.parse_iso8601_duration("garbage") == 0.0
    end
  end

  describe "engagement_score" do
    test "4% engagement maps to 100" do
      assert Util.engagement_score(0.04) == 100.0
    end

    test "clamps above 100" do
      assert Util.engagement_score(0.5) == 100.0
    end

    test "floors at 0" do
      assert Util.engagement_score(-0.1) == 0.0
    end
  end

  describe "stats" do
    test "mean" do
      assert Util.mean([1, 2, 3]) == 2.0
      assert Util.mean([]) == 0.0
    end

    test "median odd and even" do
      assert Util.median([3, 1, 2]) == 2
      assert Util.median([4, 1, 3, 2]) == 2.5
      assert Util.median([]) == 0.0
    end

    test "pstdev" do
      assert Util.pstdev([2]) == 0.0
      assert_in_delta Util.pstdev([2, 4, 4, 4, 5, 5, 7, 9]), 2.0, 0.01
    end
  end
end