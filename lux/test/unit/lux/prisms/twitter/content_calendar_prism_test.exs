defmodule Lux.Prisms.Twitter.ContentCalendarPrismTest do
  use ExUnit.Case, async: true
  doctest Lux.Prisms.Twitter.ContentCalendarPrism

  describe "run/1" do
    test "generates calendar with required fields" do
      assert {:ok, result} = Lux.Prisms.Twitter.ContentCalendarPrism.run(%{
        week_start: "2024-01-15"
      })

      assert result[:calendar] != nil
      assert result[:summary] != nil
      assert result[:recommendations] != nil
    end

    test "generates correct number of posts for single week" do
      {:ok, result} = Lux.Prisms.Twitter.ContentCalendarPrism.run(%{
        week_start: "2024-01-15",
        posts_per_day: 2
      })

      calendar = result[:calendar]
      # 7 days * 2 posts = 14 posts (Monday-Sunday)
      assert length(calendar) == 14
    end

    test "generates calendar for multiple weeks" do
      {:ok, result} = Lux.Prisms.Twitter.ContentCalendarPrism.run(%{
        week_start: "2024-01-15",
        duration_weeks: 2,
        posts_per_day: 1
      })

      calendar = result[:calendar]
      # 14 days * 1 post = 14 posts
      assert length(calendar) == 14
    end

    test "respects exclude_dates" do
      {:ok, result} = Lux.Prisms.Twitter.ContentCalendarPrism.run(%{
        week_start: "2024-01-15",
        posts_per_day: 2,
        exclude_dates: ["2024-01-15", "2024-01-16"]
      })

      calendar = result[:calendar]
      # 5 days * 2 posts = 10 posts (excluded 2 days)
      assert length(calendar) == 10
    end

    test "calendar entries have expected fields" do
      {:ok, result} = Lux.Prisms.Twitter.ContentCalendarPrism.run(%{
        week_start: "2024-01-15",
        posts_per_day: 1
      })

      [first_entry | _] = result[:calendar]
      assert first_entry[:date] != nil
      assert first_entry[:time] != nil
      assert first_entry[:category] != nil
      assert first_entry[:content_type] != nil
      assert first_entry[:topic] != nil
      assert first_entry[:suggested_content] != nil
      assert first_entry[:priority] != nil
    end

    test "summary has correct total_posts" do
      {:ok, result} = Lux.Prisms.Twitter.ContentCalendarPrism.run(%{
        week_start: "2024-01-15",
        posts_per_day: 3
      })

      assert result[:summary][:total_posts] == 21  # 7 * 3
    end

    test "summary has category_distribution" do
      {:ok, result} = Lux.Prisms.Twitter.ContentCalendarPrism.run(%{
        week_start: "2024-01-15",
        posts_per_day: 2,
        content_categories: ["analysis", "news"]
      })

      distribution = result[:summary][:category_distribution]
      assert Map.has_key?(distribution, "analysis")
      assert Map.has_key?(distribution, "news")
    end

    test "summary has daily_average" do
      {:ok, result} = Lux.Prisms.Twitter.ContentCalendarPrism.run(%{
        week_start: "2024-01-15",
        posts_per_day: 2
      })

      assert result[:summary][:daily_average] == 2.0
    end

    test "summary has optimal_posting_times" do
      {:ok, result} = Lux.Prisms.Twitter.ContentCalendarPrism.run(%{
        week_start: "2024-01-15",
        posts_per_day: 2
      })

      optimal_times = result[:summary][:optimal_posting_times]
      assert is_list(optimal_times)
      assert length(optimal_times) <= 3
    end

    test "has correct prism metadata" do
      assert Lux.Prisms.Twitter.ContentCalendarPrism.__meta__(:name) == "Content Calendar"
    end

    test "input schema has required fields" do
      schema = Lux.Prisms.Twitter.ContentCalendarPrism.__input_schema__()
      assert "week_start" in schema[:required]
    end

    test "respects content_categories parameter" do
      {:ok, result} = Lux.Prisms.Twitter.ContentCalendarPrism.run(%{
        week_start: "2024-01-15",
        posts_per_day: 2,
        content_categories: ["news", "engagement"]
      })

      categories = result[:calendar] |> Enum.map(& &1.category) |> Enum.uniq()
      assert categories == ["news", "engagement"]
    end
  end
end
