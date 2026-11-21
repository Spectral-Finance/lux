defmodule Lux.Prisms.YouTube.ModelsTest do
  use ExUnit.Case, async: true
  alias Lux.Prisms.YouTube.Models
  alias Lux.Prisms.YouTube.Models.{PostingTimeOptimizer, PerformancePredictor}

  describe "linear algebra" do
    test "transpose" do
      assert Models.transpose([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]) == [
               [1.0, 4.0],
               [2.0, 5.0],
               [3.0, 6.0]
             ]
    end

    test "matmul identity" do
      a = [[1.0, 2.0], [3.0, 4.0]]
      i = Models.identity(2)
      assert Models.matmul(a, i) == a
    end

    test "dot" do
      assert Models.dot([1.0, 2.0, 3.0], [4.0, 5.0, 6.0]) == 32.0
    end

    test "solve a x = b" do
      # 2x + y = 5 ; x + 3y = 10  => x=1, y=3
      a = [[2.0, 1.0], [1.0, 3.0]]
      b = [5.0, 10.0]
      assert {:ok, x} = Models.solve(a, b)
      assert_in_delta Enum.at(x, 0), 1.0, 1.0e-9
      assert_in_delta Enum.at(x, 1), 3.0, 1.0e-9
    end

    test "solve singular matrix returns error" do
      a = [[1.0, 2.0], [2.0, 4.0]]
      b = [1.0, 2.0]
      assert {:error, :singular_matrix} = Models.solve(a, b)
    end
  end

  describe "linear_regression" do
    test "recovers a perfect linear relationship" do
      # y = 2*x1 + 3*x2 + 5 (intercept); non-collinear features
      x = Enum.map(1..20, fn i -> [i * 1.0, rem(i * 7, 13) * 1.0] end)
      y = Enum.map(1..20, fn i -> 2.0 * i + 3.0 * rem(i * 7, 13) + 5.0 end)

      {:ok, w} = Models.linear_regression(x, y, fit_intercept: true)
      # weights: [intercept, w1, w2]
      assert_in_delta Enum.at(w, 0), 5.0, 1.0e-6
      assert_in_delta Enum.at(w, 1), 2.0, 1.0e-6
      assert_in_delta Enum.at(w, 2), 3.0, 1.0e-6

      preds = Models.predict_linear(x, w, true)
      assert_in_delta Models.r_squared(y, preds), 1.0, 1.0e-9
    end

    test "empty data returns error" do
      assert {:error, :empty_data} = Models.linear_regression([], [], [])
    end

    test "length mismatch returns error" do
      assert {:error, :length_mismatch} = Models.linear_regression([[1.0]], [1.0, 2.0], [])
    end
  end

  describe "logistic_regression" do
    test "learns a separable boundary" do
      # class 1 when x1 + x2 >= 0, else 0
      x =
        Enum.flat_map(-5..5, fn a ->
          Enum.map(-5..5, fn b -> [a * 1.0, b * 1.0] end)
        end)

      y = Enum.map(x, fn [a, b] -> if a + b >= 0, do: 1, else: 0 end)

      {:ok, w} = Models.logistic_regression(x, y, learning_rate: 0.1, epochs: 2000)
      probs = Models.predict_proba(x, w, true)
      labels = Models.predict_labels(probs, 0.5)
      acc = Models.accuracy(labels, y)
      assert acc > 0.9
    end
  end

  describe "PostingTimeOptimizer" do
    test "finds the best slot with smoothing" do
      o =
        PostingTimeOptimizer.new(2.0)
        |> PostingTimeOptimizer.add(0, 9, 0.1)
        |> PostingTimeOptimizer.add(0, 9, 0.2)
        |> PostingTimeOptimizer.add(3, 14, 0.05)
        |> PostingTimeOptimizer.add(3, 14, 0.05)

      # Monday 9am has higher mean engagement than Thursday 2pm
      best = PostingTimeOptimizer.best_slot(o)
      assert best.day == 0
      assert best.hour == 9
      assert best.day_name == "Mon"

      times = PostingTimeOptimizer.best_times(o, 2)
      assert length(times) == 2
      assert hd(times).day == 0
    end

    test "empty optimizer returns nil best slot" do
      assert PostingTimeOptimizer.best_slot(PostingTimeOptimizer.new()) == nil
      assert PostingTimeOptimizer.best_times(PostingTimeOptimizer.new(), 5) == []
    end
  end

  describe "PerformancePredictor" do
    test "fits and predicts views with a confidence band" do
      videos =
        Enum.map(1..30, fn i ->
          %{
            title: String.duplicate("x", rem(i, 40)),
            tags: Enum.map(1..rem(i, 8), fn _ -> "t" end),
            description: String.duplicate("d", i),
            has_thumbnail: true,
            published_hour: rem(i, 24),
            published_day: rem(i, 7),
            views: 100 * i
          }
        end)

      {:ok, p} = PerformancePredictor.fit(PerformancePredictor.new(1.0), videos)
      {:ok, pred} = PerformancePredictor.predict(p, %{title: "hello", tags: ["a", "b"], views: 0})

      assert pred.predicted_views >= 0.0
      assert pred.lower <= pred.upper
      assert pred.confidence_std >= 0.0

      {:ok, importance} = PerformancePredictor.feature_importance(p)
      assert map_size(importance) == 6
      assert Map.has_key?(importance, "title_len")
    end

    test "predict before fit returns error" do
      assert {:error, :not_fitted} =
               PerformancePredictor.predict(PerformancePredictor.new(), %{title: "x"})
    end

    test "featurize produces 6 features" do
      f = PerformancePredictor.featurize(%{title: "abc", tags: ["x"], description: "hi"})
      assert length(f) == 6
      assert Enum.at(f, 0) == 3.0
      assert Enum.at(f, 1) == 1.0
    end
  end
end
