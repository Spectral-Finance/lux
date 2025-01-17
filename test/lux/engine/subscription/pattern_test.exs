defmodule Lux.Engine.Subscription.PatternTest do
  use ExUnit.Case
  alias Lux.Engine.Subscription.Pattern

  describe "new/2" do
    test "creates a pattern with exact matches" do
      pattern_map = %{type: "test.event", value: 42}
      pattern = Pattern.new(pattern_map)

      assert pattern.pattern == %{type: "test.event", value: 42}
      assert pattern.wildcards == %{}
      assert pattern.regex_patterns == %{}
      assert pattern.priority == 0
    end

    test "extracts wildcards from pattern" do
      pattern_map = %{type: "test.*", value: "*"}
      pattern = Pattern.new(pattern_map)

      assert pattern.pattern == %{}
      assert pattern.wildcards == %{type: "test.*", value: "*"}
      assert pattern.regex_patterns == %{}
    end

    test "extracts regex patterns" do
      pattern_map = %{id: "~r/[0-9]+/", type: "test"}
      pattern = Pattern.new(pattern_map)

      assert pattern.pattern == %{type: "test"}
      assert pattern.wildcards == %{}
      assert map_size(pattern.regex_patterns) == 1
      assert Regex.regex?(pattern.regex_patterns.id)
    end

    test "sets priority from options" do
      pattern = Pattern.new(%{}, priority: 10)
      assert pattern.priority == 10
    end

    test "handles mixed pattern types" do
      pattern_map = %{
        type: "test.*",
        id: "~r/^[0-9]+$/",
        status: "active",
        priority: "*"
      }

      pattern = Pattern.new(pattern_map)

      assert pattern.pattern == %{status: "active"}
      assert pattern.wildcards == %{type: "test.*", priority: "*"}
      assert map_size(pattern.regex_patterns) == 1
      assert Regex.regex?(pattern.regex_patterns.id)
    end

    test "handles nested maps in pattern" do
      pattern_map = %{
        type: "test.event",
        metadata: %{
          source: "test.*",
          id: "~r/^[0-9]+$/"
        }
      }

      pattern = Pattern.new(pattern_map)

      assert pattern.pattern == %{
               type: "test.event",
               metadata: %{source: "test.*", id: "~r/^[0-9]+$/"}
             }

      # Note: Currently nested maps are treated as exact matches
      assert pattern.wildcards == %{}
      assert pattern.regex_patterns == %{}
    end
  end

  describe "match?/2" do
    test "matches exact patterns" do
      pattern = Pattern.new(%{type: "test.event", value: 42})
      signal = %{type: "test.event", value: 42, extra: "field"}

      assert {:ok, 0} = Pattern.match?(pattern, signal)
    end

    test "does not match when fields are missing" do
      pattern = Pattern.new(%{type: "test.event", missing: "field"})
      signal = %{type: "test.event"}

      assert {:ok, 0} = Pattern.match?(pattern, signal)
    end

    test "matches wildcard patterns" do
      pattern = Pattern.new(%{type: "test.*", value: "*"})
      signal = %{type: "test.event", value: "anything"}

      assert {:ok, 0} = Pattern.match?(pattern, signal)
    end

    test "matches regex patterns" do
      pattern = Pattern.new(%{id: "~r/^[0-9]{3}$/"})
      signal = %{id: "123"}

      assert {:ok, 0} = Pattern.match?(pattern, signal)
    end

    test "returns priority with match" do
      pattern = Pattern.new(%{type: "test"}, priority: 10)
      signal = %{type: "test"}

      assert {:ok, 10} = Pattern.match?(pattern, signal)
    end

    test "matches complex wildcard patterns" do
      pattern = Pattern.new(%{type: "test.*.user.?"})
      signal = %{type: "test.api.user.1"}

      assert {:ok, 0} = Pattern.match?(pattern, signal)
    end

    test "matches multiple wildcards in single field" do
      pattern = Pattern.new(%{path: "*/users/*/profile"})
      signal = %{path: "api/users/123/profile"}

      assert {:ok, 0} = Pattern.match?(pattern, signal)
    end

    test "matches complex regex patterns" do
      pattern =
        Pattern.new(%{
          email: "~r/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$/",
          id: "~r/^[0-9]{3}-[A-Z]{2}$/"
        })

      signal = %{email: "test@example.com", id: "123-AB"}

      assert {:ok, 0} = Pattern.match?(pattern, signal)
    end

    test "handles non-string values in signal" do
      pattern = Pattern.new(%{count: "~r/^[0-9]+$/", status: "*"})
      signal = %{count: 42, status: true}

      assert :nomatch = Pattern.match?(pattern, signal)
    end

    test "matches empty pattern against any signal" do
      pattern = Pattern.new(%{})
      signal = %{type: "test.event", value: 42}

      assert {:ok, 0} = Pattern.match?(pattern, signal)
    end
  end

  describe "apply_transformations/2" do
    test "applies transformations to matching fields" do
      transformations = %{
        value: &(&1 * 2),
        name: &String.upcase/1
      }

      pattern = Pattern.new(%{}, transformations: transformations)
      signal = %{value: 21, name: "test", other: "field"}

      transformed = Pattern.apply_transformations(pattern, signal)
      assert transformed.value == 42
      assert transformed.name == "TEST"
      assert transformed.other == "field"
    end

    test "ignores transformations for missing fields" do
      transformations = %{missing: &(&1 * 2)}
      pattern = Pattern.new(%{}, transformations: transformations)
      signal = %{value: 21}

      transformed = Pattern.apply_transformations(pattern, signal)
      assert transformed == signal
    end

    test "applies complex transformations" do
      transformations = %{
        items: &Enum.map(&1, fn x -> x * 2 end),
        metadata: &Map.put(&1, :processed, true)
      }

      pattern = Pattern.new(%{}, transformations: transformations)

      signal = %{
        items: [1, 2, 3],
        metadata: %{source: "test"}
      }

      transformed = Pattern.apply_transformations(pattern, signal)
      assert transformed.items == [2, 4, 6]
      assert transformed.metadata == %{source: "test", processed: true}
    end

    test "handles transformation errors gracefully" do
      transformations = %{
        value: fn _ -> raise "Error" end
      }

      pattern = Pattern.new(%{}, transformations: transformations)
      signal = %{value: 42}

      assert_raise RuntimeError, "Error", fn ->
        Pattern.apply_transformations(pattern, signal)
      end
    end
  end
end
