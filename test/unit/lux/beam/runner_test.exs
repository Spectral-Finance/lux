defmodule Lux.Beam.RunnerTest do
  use UnitCase, async: true

  alias Lux.Beam.Runner

  defmodule TestPrism do
    @moduledoc false
    use Lux.Prism

    def handler(%{value: value, extra: extra}, _ctx) do
      {:ok, {"value_" <> value, "extra_" <> extra}}
    end

    def handler(%{value: value}, _ctx) do
      {:ok, value}
    end

    def handler(list, _ctx) when is_list(list) do
      {:ok, Enum.join(list, ",")}
    end
  end

  defmodule FailingPrism do
    @moduledoc false
    use Lux.Prism

    def handler(_input, _ctx) do
      {:error, "failed"}
    end
  end

  defmodule TestBeam do
    @moduledoc false
    use Lux.Beam,
      name: "Test Runner Beam",
      description: "A test beam for runner",
      input_schema: [value: [type: :string]],
      generate_execution_log: true

    @impl true
    def steps do
      sequence do
        step(:first, TestPrism, [:input])

        parallel do
          step(:second, TestPrism, %{value: "fixed"})
          step(:third, TestPrism, %{value: [:steps, :first, :result]})
        end

        branch {__MODULE__, :threshold_check?} do
          true ->
            step(:high, TestPrism, %{value: "above_threshold"})

          false ->
            step(:low, TestPrism, %{value: "below_threshold"})
        end
      end
    end

    def threshold_check?(ctx) do
      get_in(ctx, [:steps, :first, :result]) == "high_value"
    end
  end

  describe "run/3" do
    test "executes a successful beam" do
      assert {:ok, output, log} = Runner.run(TestBeam.beam(), %{value: "high_value"})
      assert output == "above_threshold"
      assert log.status == :completed
      # first, second, third, branch check, low
      assert length(log.steps) == 4

      # Verify each step individually without relying on order
      steps_by_id = Map.new(log.steps, &{&1.id, &1})

      # Verify first step
      assert %{
               error: nil,
               id: :first,
               input: %{value: "high_value"},
               output: "high_value",
               status: :completed,
               started_at: _,
               completed_at: _,
               step_index: 0
             } = steps_by_id[:first]

      # Verify second step
      assert %{
               error: nil,
               id: :second,
               input: %{value: "fixed"},
               output: "fixed",
               status: :completed,
               started_at: _,
               completed_at: _,
               step_index: parallel_index_1
             } = steps_by_id[:second]

      # Verify third step
      assert %{
               error: nil,
               id: :third,
               input: %{value: "high_value"},
               output: "high_value",
               status: :completed,
               started_at: _,
               completed_at: _,
               step_index: parallel_index_2
             } = steps_by_id[:third]

      assert parallel_index_1 != parallel_index_2

      # Verify low step
      assert %{
               id: :high,
               input: %{value: "above_threshold"},
               output: "above_threshold",
               status: :completed,
               started_at: _,
               completed_at: _,
               step_index: 3
             } = steps_by_id[:high]

      assert is_nil(steps_by_id[:low])

      # Verify parallel steps completed in any order
      parallel_steps = Enum.filter(log.steps, &(&1.id in [:second, :third]))
      assert length(parallel_steps) == 2
      assert Enum.all?(parallel_steps, &(&1.status == :completed))
    end

    test "handles parallel execution" do
      {:ok, _output, log} = Runner.run(TestBeam.beam(), %{value: "test"})

      parallel_steps =
        Enum.filter(log.steps, fn step ->
          step.id in [:second, :third]
        end)

      assert length(parallel_steps) == 2
      assert Enum.all?(parallel_steps, &(&1.status == :completed))
    end

    test "follows correct branch path" do
      {:ok, "above_threshold", _log} = Runner.run(TestBeam.beam(), %{value: "high_value"})
      {:ok, "below_threshold", _log} = Runner.run(TestBeam.beam(), %{value: "low_value"})
    end

    test "handles parameter references" do
      {:ok, _output, log} = Runner.run(TestBeam.beam(), %{value: "test"})

      third_step = Enum.find(log.steps, &(&1.id == :third))
      assert third_step.input.value == "test"
    end

    test "respects retry configuration" do
      defmodule RetryBeam do
        @moduledoc false
        use Lux.Beam, generate_execution_log: true

        def steps do
          sequence do
            step("retry", FailingPrism, %{}, retries: 2, retry_backoff: 10)
          end
        end
      end

      start_time = System.monotonic_time()
      {:error, "failed", log} = Runner.run(RetryBeam.beam(), %{})
      end_time = System.monotonic_time()

      retry_step = Enum.find(log.steps, &(&1.id == "retry"))
      assert retry_step.status == :failed
      # At least 20ms (2 retries * 10ms)
      assert end_time - start_time >= 20_000_000
    end

    test "generates execution log when configured" do
      {:ok, _output, log} = Runner.run(TestBeam.beam(), %{value: "test"}, agent: "test_agent")

      assert log.beam_id != nil
      assert log.started_by == "test_agent"
      assert log.started_at != nil
      assert log.completed_at != nil
      assert log.status == :completed
      assert is_list(log.steps)
    end

    test "handles step failures" do
      defmodule FailureBeam do
        @moduledoc false
        use Lux.Beam, generate_execution_log: true

        def steps do
          sequence do
            step(:will_fail, FailingPrism, %{})
          end
        end
      end

      assert {:error, "failed", log} = Runner.run(FailureBeam.beam(), %{})
      assert log.status == :failed

      failed_step = Enum.find(log.steps, &(&1.id == :will_fail))
      assert failed_step.status == :failed
      assert failed_step.error == "failed"
    end

    test "handles nested branches" do
      defmodule NestedBeam do
        @moduledoc false
        use Lux.Beam, generate_execution_log: true

        def steps do
          sequence do
            branch {__MODULE__, :first_check?} do
              true ->
                sequence do
                  step(:a1, TestPrism, %{value: "a1"})

                  branch {__MODULE__, :second_check?} do
                    true -> step(:b1, TestPrism, %{value: "b1"})
                    false -> step(:b2, TestPrism, %{value: "b2"})
                  end
                end

              false ->
                step(:a2, TestPrism, %{value: "a2"})
            end
          end
        end

        def first_check?(ctx), do: get_in(ctx, [:input, :value]) == "nested"
        def second_check?(ctx), do: get_in(ctx, [:steps, :a1, :result]) == "a1"
      end

      {:ok, output, log} = NestedBeam.run(%{value: "nested"})
      assert output == "b1"
      # a1, b1, and the final output
      assert length(log.steps) == 2

      {:ok, output, log} = NestedBeam.run(%{value: "other"})
      assert output == "a2"
      # just a2
      assert length(log.steps) == 1
    end

    test "handles complex parameter passing" do
      defmodule RefBeam do
        @moduledoc false
        use Lux.Beam, generate_execution_log: true

        def steps do
          sequence do
            step(:first, TestPrism, [:input])
            step(:second, TestPrism, %{value: [:steps, :first, :result]})

            step(:third, TestPrism, %{
              value: [:steps, :second, :result],
              extra: [:steps, :first, :result]
            })
          end
        end
      end

      {:ok, {"value_test", "extra_test"}, log} = RefBeam.run(%{value: "test"})

      third_step = Enum.find(log.steps, &(&1.id == :third))
      assert third_step.input.value == "test"
      assert third_step.input.extra == "test"
    end

    test "handles errors in parallel execution" do
      defmodule ParallelErrorBeam do
        @moduledoc false
        use Lux.Beam, generate_execution_log: true

        def steps do
          sequence do
            parallel do
              step(:success, TestPrism, %{value: "ok"})
              step(:fail, FailingPrism, %{})
            end
          end
        end
      end

      {:error, "failed", log} = Runner.run(ParallelErrorBeam.beam(), %{})

      success_step = Enum.find(log.steps, &(&1.id == :success))
      fail_step = Enum.find(log.steps, &(&1.id == :fail))

      # Success step might complete before failure
      if success_step do
        assert success_step.status in [:completed, :running]
      end

      assert fail_step.status == :failed
      assert fail_step.error == "failed"
    end

    test "handles both access paths and literal values" do
      defmodule MixedValuesBeam do
        @moduledoc false
        use Lux.Beam, generate_execution_log: true

        def steps do
          sequence do
            # Access path to input
            step(:first, TestPrism, [:input])

            # Map with access path and literal list
            step(:second, TestPrism, %{
              value: [:steps, :first, :result],
              list: [1, 2, 3],
              nested_list: [[:a, :b], [:c, :d]]
            })

            # Direct literal value as list
            step(:third, TestPrism, [4, 5, 6])
          end
        end
      end

      {:ok, _output, log} = MixedValuesBeam.run(%{value: "test"})

      steps_by_id = Map.new(log.steps, &{&1.id, &1})

      # First step gets input value
      assert steps_by_id[:first].output == "test"

      # Second step gets mix of values
      assert steps_by_id[:second].input.value == "test"
      assert steps_by_id[:second].input.list == [1, 2, 3]
      assert steps_by_id[:second].input.nested_list == [[:a, :b], [:c, :d]]

      # Third step gets literal list and joins it
      assert steps_by_id[:third].input == [4, 5, 6]
      assert steps_by_id[:third].output == "4,5,6"
    end
  end

  describe "branch validation" do
    test "validates branch condition is properly serialized" do
      steps = TestBeam.steps()
      {:sequence, steps_list} = steps
      branch = List.last(steps_list)

      assert {:branch, {TestBeam, :threshold_check?}, branches} = branch
      assert is_list(branches)
      assert Keyword.has_key?(branches, true)
      assert Keyword.has_key?(branches, false)
    end

    test "validates branch steps have correct structure" do
      steps = TestBeam.steps()
      {:sequence, steps_list} = steps
      {:branch, _, branches} = List.last(steps_list)

      high_step = branches[true]
      low_step = branches[false]

      assert high_step.id == :high
      assert high_step.params.value == "above_threshold"
      assert low_step.id == :low
      assert low_step.params.value == "below_threshold"
    end
  end

  test "steps, inputs, outputs, and logs are as expected" do
    defmodule A do
      @moduledoc false
      use Lux.Prism,
        name: "#{A}",
        id: A,
        input_schema: %{type: "string"}

      def handler("expected A input", _ctx) do
        {:ok, "expected B input"}
      end
    end

    defmodule B do
      @moduledoc false
      use Lux.Prism,
        name: "#{B}",
        id: B,
        input_schema: %{type: "string"}

      def handler("expected B input", _ctx) do
        {:ok, "B output"}
      end
    end

    defmodule CBeam do
      @moduledoc false
      use Lux.Beam,
        name: "#{CBeam}",
        id: CBeam,
        input_schema: %{type: "object", properties: %{a: %{type: "string"}}},
        generate_execution_log: true

      def steps do
        sequence do
          step(:a, A, [:input, :a])
          step(:b, B, [:steps, :a, :result])
        end
      end
    end

    assert {:ok, "B output",
            %{
              input: %{a: "expected A input"},
              output: "B output",
              status: :completed,
              # matches the first step
              started_at: started_at,
              steps: [
                %{
                  error: nil,
                  id: :a,
                  input: "expected A input",
                  output: "expected B input",
                  status: :completed,
                  started_at: started_at,
                  completed_at: _,
                  step_index: 0
                },
                %{
                  error: nil,
                  id: :b,
                  input: "expected B input",
                  output: "B output",
                  status: :completed,
                  started_at: _,
                  completed_at: completed_at,
                  step_index: 1
                }
              ],
              # matches the last step
              completed_at: completed_at,
              beam_id: Lux.Beam.RunnerTest.CBeam,
              started_by: "system"
            }} = CBeam.run(%{a: "expected A input"})

    assert started_at
    assert completed_at
  end

  describe "fallbacks" do
    test "fallback has access to context" do
      defmodule ContextFallbackBeam do
        @moduledoc false
        use Lux.Beam

        def steps do
          sequence do
            step(:first, TestPrism, %{value: 123})

            step(:second, TestPrism, %{fail: true},
              fallback: fn %{context: ctx} ->
                {:continue, %{previous_value: get_in(ctx, [:steps, :first, :result])}}
              end
            )
          end
        end
      end

      {:ok, result, _log} = ContextFallbackBeam.run(%{})
      assert result.previous_value == 123
    end

    test "retries are attempted before fallback" do
      defmodule RetryThenFallbackBeam do
        @moduledoc false
        use Lux.Beam,
          generate_execution_log: true

        def steps do
          sequence do
            step(:test, TestPrism, %{fail: true},
              retries: 2,
              retry_backoff: 1,
              fallback: fn %{error: _error} ->
                {:continue, %{retried: true}}
              end
            )
          end
        end
      end

      {:ok, result, log} = RetryThenFallbackBeam.run(%{})
      assert result.retried == true

      assert [
               %{
                 error: nil,
                 id: :test,
                 input: %{fail: true},
                 output: %{retried: true},
                 status: :completed,
                 started_at: _,
                 completed_at: _
               }
             ] = log.steps
    end
  end
end
