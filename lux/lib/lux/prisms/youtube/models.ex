defmodule Lux.Prisms.YouTube.Models do
  @moduledoc """
  Dependency-free machine-learning models for YouTube content optimization
  (lux issue #69 — "Machine learning models for content optimization" and
  "Performance prediction system").

  Pure Elixir, no external deps, fully deterministic. Covers:

    * `linear_regression/3` — ordinary least squares via the closed-form normal
      equation, solved with Gaussian elimination (optional L2/ridge penalty).
    * `logistic_regression/4` — binary classification trained with batch
      gradient descent ("will this video be a hit?").
    * `PostingTimeOptimizer` — learns the best hour-of-week to publish from
      historical engagement, with Bayesian smoothing so sparse buckets degrade
      gracefully.
    * `PerformancePredictor` — ties a ridge regression over engineered video
      features into a single `predict/2` returning an expected-views estimate
      plus a ±1σ confidence band derived from residual variance.

  All functions are side-effect free and unit-testable.
  """

  @typedoc "A dense row-major matrix: list of rows, each a list of floats."
  @type matrix :: [[float()]]

  @typedoc "A dense vector."
  @type vector :: [float()]

  # --------------------------------------------------------------------------- #
  # Linear algebra helpers
  # --------------------------------------------------------------------------- #
  @doc "Transpose a matrix."
  @spec transpose(matrix()) :: matrix()
  def transpose(matrix) do
    matrix
    |> Enum.zip()
    |> Enum.map(fn tuple -> tuple |> Tuple.to_list() |> Enum.map(& &1) end)
  end

  @doc "Matrix multiply `a` × `b`."
  @spec matmul(matrix(), matrix()) :: matrix()
  def matmul(a, b) do
    bt = transpose(b)

    Enum.map(a, fn row ->
      Enum.map(bt, fn col -> dot(row, col) end)
    end)
  end

  @doc "Matrix × vector."
  @spec matvec(matrix(), vector()) :: vector()
  def matvec(a, v) do
    Enum.map(a, fn row -> dot(row, v) end)
  end

  @doc "Dot product of two equal-length vectors."
  @spec dot(vector(), vector()) :: float()
  def dot(u, v) do
    u
    |> Enum.zip(v)
    |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * y end)
  end

  @doc "Build an n×n identity matrix."
  @spec identity(non_neg_integer()) :: matrix()
  def identity(n) do
    Enum.map(0..(n - 1), fn i ->
      Enum.map(0..(n - 1), fn j -> if i == j, do: 1.0, else: 0.0 end)
    end)
  end

  @doc """
  Solve `a x = b` via Gaussian elimination with partial pivoting.
  Returns `{:ok, x}` or `{:error, :singular_matrix}`.
  """
  @spec solve(matrix(), vector()) :: {:ok, vector()} | {:error, :singular_matrix}
  def solve(a, b) do
    n = length(a)

    # Augmented matrix [a | b]
    aug =
      a
      |> Enum.zip(b)
      |> Enum.map(fn {row, bi} -> row ++ [bi] end)

    case eliminate(aug, n) do
      nil ->
        {:error, :singular_matrix}

      m ->
        x =
          Enum.map(0..(n - 1), fn i ->
            Enum.at(m, i) |> Enum.at(n) |> Kernel./(Enum.at(m, i) |> Enum.at(i))
          end)

        {:ok, x}
    end
  end

  defp eliminate(m, n) do
    m = to_float_matrix(m)

    result =
      Enum.reduce(0..(n - 1), {:ok, m}, fn col, {:ok, acc} ->
        # find pivot
        {pivot_row, _} =
          Enum.reduce(col..(n - 1), {col, 0.0}, fn r, {_, best} ->
            val = abs(Enum.at(Enum.at(acc, r), col))

            if val > best, do: {r, val}, else: {r, best}
          end)

        pivot_val = Enum.at(Enum.at(acc, pivot_row), col)

        if abs(pivot_val) < 1.0e-12 do
          {:error, :singular}
        else
          # swap rows
          acc = swap_rows(acc, col, pivot_row)
          pv = Enum.at(Enum.at(acc, col), col)

          acc =
            Enum.reduce(0..(n - 1), acc, fn r, a2 ->
              if r == col do
                a2
              else
                factor = Enum.at(Enum.at(a2, r), col) |> Kernel./(pv)

                if factor == 0.0 do
                  a2
                else
                  eliminate_row(a2, r, col, factor, n)
                end
              end
            end)

          {:ok, acc}
        end
      end)

    case result do
      {:ok, m} -> m
      {:error, _} -> nil
    end
  end

  defp eliminate_row(m, r, col, factor, n) do
    row_r = Enum.at(m, r)
    row_c = Enum.at(m, col)

    new_row =
      Enum.reduce(0..n, row_r, fn c, row ->
        val = Enum.at(row, c) - factor * Enum.at(row_c, c)
        List.replace_at(row, c, val)
      end)

    List.replace_at(m, r, new_row)
  end

  defp swap_rows(m, i, j) do
    ri = Enum.at(m, i)
    rj = Enum.at(m, j)
    m |> List.replace_at(i, rj) |> List.replace_at(j, ri)
  end

  defp to_float_matrix(m) do
    Enum.map(m, fn row -> Enum.map(row, &to_float/1) end)
  end

  defp to_float(x) when is_float(x), do: x
  defp to_float(x) when is_integer(x), do: x * 1.0
  defp to_float(x) when is_binary(x), do: x |> Float.parse() |> elem(0)

  # --------------------------------------------------------------------------- #
  # Linear regression (closed-form OLS with optional L2/ridge)
  # --------------------------------------------------------------------------- #
  @doc """
  Fit ordinary least squares `y = X w` by solving the (optionally
  ridge-regularised) normal equation `(XᵀX + λI) w = Xᵀy`.

  Options:
    * `:l2` — ridge penalty λ (default `0.0` = plain OLS)
    * `:fit_intercept` — prepend a bias column of ones (default `true`)

  Returns `{:ok, weights}` or `{:error, reason}`.
  """
  @spec linear_regression(matrix(), vector(), keyword()) ::
          {:ok, vector()} | {:error, atom()}
  def linear_regression(x, y, opts \\ []) do
    l2 = Keyword.get(opts, :l2, 0.0)
    fit_intercept = Keyword.get(opts, :fit_intercept, true)

    if length(x) != length(y) do
      {:error, :length_mismatch}
    else
      if x == [] do
        {:error, :empty_data}
      else
        design = design_matrix(x, fit_intercept)
        n_features = length(hd(design))

        xt = transpose(design)
        xtx = matmul(xt, design)
        xty = matvec(xt, Enum.map(y, &to_float/1))

        xtx = maybe_ridge(xtx, l2, fit_intercept, n_features)

        solve(xtx, xty)
      end
    end
  end

  @doc "Predict `y` values from `x` using fitted `weights`."
  @spec predict_linear(matrix(), vector(), boolean()) :: vector()
  def predict_linear(x, weights, fit_intercept \\ true) do
    design = design_matrix(x, fit_intercept)
    matvec(design, weights)
  end

  @doc "Coefficient of determination R² between predictions and truth."
  @spec r_squared(vector(), vector()) :: float()
  def r_squared(y, preds) do
    ybar = mean(y)

    ss_tot =
      y |> Enum.reduce(0.0, fn yi, acc -> acc + (yi - ybar) * (yi - ybar) end)

    ss_res =
      y
      |> Enum.zip(preds)
      |> Enum.reduce(0.0, fn {yi, pi}, acc -> acc + (yi - pi) * (yi - pi) end)

    cond do
      ss_tot == 0.0 -> if ss_res == 0.0, do: 1.0, else: 0.0
      true -> 1.0 - ss_res / ss_tot
    end
  end

  @doc "Residual standard deviation (population) of predictions vs truth."
  @spec residual_std(vector(), vector()) :: float()
  def residual_std(y, preds) do
    residuals =
      y
      |> Enum.zip(preds)
      |> Enum.map(fn {yi, pi} -> yi - pi end)

    if length(residuals) > 1, do: pstdev(residuals), else: 0.0
  end

  defp design_matrix(x, fit_intercept) do
    Enum.map(x, fn row ->
      r = Enum.map(row, &to_float/1)
      if fit_intercept, do: [1.0 | r], else: r
    end)
  end

  defp maybe_ridge(xtx, l2, fit_intercept, n_features) do
    if l2 > 0.0 do
      start = if fit_intercept, do: 1, else: 0

      xtx
      |> Enum.with_index()
      |> Enum.map(fn {row, i} ->
        row
        |> Enum.with_index()
        |> Enum.map(fn {val, j} ->
          if i >= start and i == j, do: val + l2, else: val
        end)
      end)
    else
      xtx
    end
  end

  # --------------------------------------------------------------------------- #
  # Logistic regression (batch gradient descent)
  # --------------------------------------------------------------------------- #
  @doc "Numerically stable sigmoid."
  @spec sigmoid(number()) :: float()
  def sigmoid(z) when z >= 0 do
    1.0 / (1.0 + :math.exp(-z))
  end

  def sigmoid(z) do
    ez = :math.exp(z)
    ez / (1.0 + ez)
  end

  @doc """
  Train binary logistic regression with batch gradient descent.

  Options:
    * `:learning_rate` (default `0.1`)
    * `:epochs` (default `500`)
    * `:l2` (default `0.0`)
    * `:fit_intercept` (default `true`)

  Returns `{:ok, weights}`.
  """
  @spec logistic_regression(matrix(), [non_neg_integer()], keyword()) ::
          {:ok, vector()} | {:error, atom()}
  def logistic_regression(x, y, opts \\ []) do
    lr = Keyword.get(opts, :learning_rate, 0.1)
    epochs = Keyword.get(opts, :epochs, 500)
    l2 = Keyword.get(opts, :l2, 0.0)
    fit_intercept = Keyword.get(opts, :fit_intercept, true)

    if length(x) != length(y) or x == [] do
      {:error, :bad_input}
    else
      design = design_matrix(x, fit_intercept)
      n = length(hd(design))
      m = length(design)
      start = if fit_intercept, do: 1, else: 0

      weights =
        Enum.reduce(1..epochs, List.duplicate(0.0, n), fn _epoch, w ->
          grad =
            design
            |> Enum.zip(Enum.map(y, &to_float/1))
            |> Enum.reduce(List.duplicate(0.0, n), fn {row, label}, g ->
              pred = sigmoid(dot(w, row))
              err = pred - label

              g
              |> Enum.with_index()
              |> Enum.map(fn {gj, j} -> gj + err * Enum.at(row, j) end)
            end)

          w
          |> Enum.with_index()
          |> Enum.map(fn {wj, j} ->
            reg = if j >= start, do: l2 * wj, else: 0.0
            wj - lr * (Enum.at(grad, j) / m + reg)
          end)
        end)

      {:ok, weights}
    end
  end

  @doc "Predict class probabilities `P(y=1|x)` from fitted logistic weights."
  @spec predict_proba(matrix(), vector(), boolean()) :: [float()]
  def predict_proba(x, weights, fit_intercept \\ true) do
    design = design_matrix(x, fit_intercept)
    Enum.map(design, fn row -> sigmoid(dot(weights, row)) end)
  end

  @doc "Predict hard 0/1 labels from probabilities."
  @spec predict_labels([float()], number()) :: [non_neg_integer()]
  def predict_labels(probs, threshold \\ 0.5) do
    Enum.map(probs, fn p -> if p >= threshold, do: 1, else: 0 end)
  end

  @doc "Mean classification accuracy."
  @spec accuracy([non_neg_integer()], [non_neg_integer()]) :: float()
  def accuracy(preds, truth) do
    if truth == [] do
      0.0
    else
      correct =
        preds
        |> Enum.zip(truth)
        |> Enum.count(fn {p, t} -> p == t end)

      correct / length(truth)
    end
  end

  # --------------------------------------------------------------------------- #
  # Posting-time optimizer
  # --------------------------------------------------------------------------- #
  defmodule PostingTimeOptimizer do
    @moduledoc """
    Learn the best hour-of-week to publish from historical engagement.

    Engagement is aggregated into 7×24 = 168 buckets (day-of-week × hour). Each
    bucket's mean engagement is smoothed toward the global mean with a
    Bayesian-style prior (`:smoothing` pseudo-count) so sparse buckets don't win
    by luck. `best_times/2` returns the top buckets ranked by smoothed score.
    """

    @days ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    defstruct sums: %{}, counts: %{}, global_sum: 0.0, global_n: 0, smoothing: 2.0

    @type t :: %__MODULE__{
            sums: %{optional(non_neg_integer()) => float()},
            counts: %{optional(non_neg_integer()) => non_neg_integer()},
            global_sum: float(),
            global_n: non_neg_integer(),
            smoothing: float()
          }

    @doc "Create an optimizer. `smoothing` is the Bayesian prior pseudo-count."
    @spec new(number()) :: t()
    def new(smoothing \\ 2.0) do
      %__MODULE__{smoothing: smoothing * 1.0}
    end

    @doc "Record one observation. `day` is 0=Mon..6=Sun, `hour` 0..23."
    @spec add(t(), non_neg_integer(), non_neg_integer(), number()) :: t()
    def add(%__MODULE__{} = o, day, hour, engagement) do
      b = bucket(day, hour)
      e = to_float(engagement)

      %__MODULE__{
        o
        | sums: Map.update(o.sums, b, e, &(&1 + e)),
          counts: Map.update(o.counts, b, 1, &(&1 + 1)),
          global_sum: o.global_sum + e,
          global_n: o.global_n + 1
      }
    end

    @doc "Fit from an enumerable of `{day, hour, engagement}` tuples."
    @spec fit(t(), Enumerable.t()) :: t()
    def fit(%__MODULE__{} = o, observations) do
      Enum.reduce(observations, o, fn {d, h, e}, acc -> add(acc, d, h, e) end)
    end

    @doc "Smoothed expected engagement for a (day, hour) slot."
    @spec score(t(), non_neg_integer(), non_neg_integer()) :: float()
    def score(%__MODULE__{} = o, day, hour) do
      b = bucket(day, hour)
      n = Map.get(o.counts, b, 0)
      s = Map.get(o.sums, b, 0.0)
      prior = global_mean(o)
      (s + o.smoothing * prior) / (n + o.smoothing)
    end

    @doc "Return the top_k best (day, hour) slots ranked by smoothed score."
    @spec best_times(t(), non_neg_integer()) :: [map()]
    def best_times(%__MODULE__{} = o, top_k \\ 5) do
      if map_size(o.counts) == 0 do
        []
      else
        o.sums
        |> Enum.map(fn {b, _} ->
          day = div(b, 24)
          hour = rem(b, 24)

          %{
            day: day,
            day_name: Enum.at(@days, day),
            hour: hour,
            score: score(o, day, hour),
            samples: Map.get(o.counts, b, 0)
          }
        end)
        |> Enum.sort_by(& &1.score, :desc)
        |> Enum.take(top_k)
      end
    end

    @doc "Return the single best slot, or nil if no data."
    @spec best_slot(t()) :: map() | nil
    def best_slot(%__MODULE__{} = o) do
      case best_times(o, 1) do
        [best | _] -> best
        [] -> nil
      end
    end

    defp bucket(day, hour), do: rem(day, 7) * 24 + rem(hour, 24)

    defp global_mean(%__MODULE__{global_n: 0}), do: 0.0
    defp global_mean(%__MODULE__{} = o), do: o.global_sum / o.global_n

    defp to_float(x) when is_float(x), do: x
    defp to_float(x) when is_integer(x), do: x * 1.0
  end

  # --------------------------------------------------------------------------- #
  # Performance predictor
  # --------------------------------------------------------------------------- #
  defmodule PerformancePredictor do
    @moduledoc """
    End-to-end view-count predictor.

    Combines a ridge `LinearRegression` over engineered video features with a
    residual-variance confidence band. Satisfies the "Performance prediction
    system" acceptance criterion of lux issue #69.

    Engineered features (in order):
      `[title_len, tag_count, description_len, has_thumbnail, hour, day]`
    """

    alias Lux.Prisms.YouTube.Models

    @feature_names [
      "title_len",
      "tag_count",
      "description_len",
      "has_thumbnail",
      "hour",
      "day"
    ]

    defstruct weights: nil, resid_std: 0.0, l2: 1.0

    @type t :: %__MODULE__{
            weights: [float()] | nil,
            resid_std: float(),
            l2: float()
          }

    @doc "Create an unfitted predictor. `l2` is the ridge penalty (default 1.0)."
    @spec new(number()) :: t()
    def new(l2 \\ 1.0), do: %__MODULE__{l2: l2 * 1.0}

    @doc "Turn a raw video map into the model's numeric feature vector."
    @spec featurize(map()) :: [float()]
    def featurize(video) when is_map(video) do
      snippet = Map.get(video, :snippet, %{})
      snippet = if is_map(snippet), do: snippet, else: %{}

      title = to_string(Map.get(snippet, :title, Map.get(video, :title, "")))
      desc = to_string(Map.get(snippet, :description, Map.get(video, :description, "")))
      tags = Map.get(snippet, :tags, Map.get(video, :tags, [])) || []

      published = Map.get(video, :published_hour, Map.get(video, :hour, 12))
      day = Map.get(video, :published_day, Map.get(video, :day, 0))
      has_thumb = if Map.get(video, :has_thumbnail, true), do: 1.0, else: 0.0

      [
        String.length(title) * 1.0,
        length(tags) * 1.0,
        String.length(desc) * 1.0,
        has_thumb,
        published * 1.0,
        day * 1.0
      ]
    end

    @doc "Fit on a list of video maps each carrying a `:views` field."
    @spec fit(t(), [map()]) :: {:ok, t()} | {:error, atom()}
    def fit(%__MODULE__{} = p, videos) do
      xs = Enum.map(videos, &featurize/1)
      ys = Enum.map(videos, fn v -> Map.get(v, :views, 0) * 1.0 end)

      case Models.linear_regression(xs, ys, l2: p.l2, fit_intercept: true) do
        {:ok, weights} ->
          preds = Models.predict_linear(xs, weights, true)
          resid_std = Models.residual_std(ys, preds)
          {:ok, %__MODULE__{p | weights: weights, resid_std: resid_std}}

        error ->
          error
      end
    end

    @doc "Predict expected views with a ±1σ confidence band."
    @spec predict(t(), map()) :: {:ok, map()} | {:error, :not_fitted}
    def predict(%__MODULE__{weights: nil}, _video), do: {:error, :not_fitted}

    def predict(%__MODULE__{} = p, video) do
      x = featurize(video)
      [point] = Models.predict_linear([x], p.weights, true)

      %{
        predicted_views: max(0.0, point),
        lower: max(0.0, point - p.resid_std),
        upper: max(0.0, point + p.resid_std),
        confidence_std: p.resid_std
      }
      |> then(&{:ok, &1})
    end

    @doc "Absolute weight per feature (larger = stronger driver)."
    @spec feature_importance(t()) :: {:ok, map()} | {:error, :not_fitted}
    def feature_importance(%__MODULE__{weights: nil}), do: {:error, :not_fitted}

    def feature_importance(%__MODULE__{weights: weights}) do
      # weights[0] is the intercept; features start at index 1
      importance =
        @feature_names
        |> Enum.with_index(1)
        |> Enum.map(fn {name, i} -> {name, abs(Enum.at(weights, i, 0.0))} end)
        |> Enum.into(%{})

      {:ok, importance}
    end

    @doc "The ordered feature names."
    @spec feature_names() :: [String.t()]
    def feature_names, do: @feature_names
  end

  # --------------------------------------------------------------------------- #
  # Small stats helpers (local, to avoid cross-module coupling)
  # --------------------------------------------------------------------------- #
  defp mean([]), do: 0.0
  defp mean(list), do: Enum.sum(list) / length(list)

  defp pstdev([]), do: 0.0

  defp pstdev(list) do
    m = mean(list)

    variance =
      list |> Enum.reduce(0.0, fn x, acc -> acc + (x - m) * (x - m) end) |> Kernel./(length(list))

    :math.sqrt(variance)
  end
end
