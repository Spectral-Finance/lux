defmodule Lux.BeamTest do
  use UnitCase, async: true

  alias Lux.Beam

  defmodule TestBeam do
    @moduledoc false
    use Lux.Beam,
      name: "Test Beam",
      description: "A test beam",
      input_schema: %{type: :object, properties: %{value: %{type: :string}}, required: ["value"]},
      output_schema: %{
        type: :object,
        properties: %{trade_id: %{type: :string}},
        required: ["trade_id"]
      }

    sequence do
      step(:first, TestPrism, %{value: :value})
      step(:first_again, TestPrism, %{value: :value})

      parallel do
        step(:second, TestPrism, %{value: "fixed"}, retries: 2)
        step(:third, TestPrism, %{value: [:steps, :first, :result]}, store_io: true)
      end

      branch &above_threshold?/1 do
        true -> step(:high, TestPrism, %{value: "high"})
        false -> step(:low, TestPrism, %{value: "low"})
      end
    end

    def above_threshold?(ctx) do
      ctx.first.value > 10
    end
  end

  describe "new/1" do
    test "creates a beam from attributes" do
      attrs = [
        id: "test-1",
        name: "Test Beam",
        description: "A test beam",
        input_schema: [value: [type: :string, required: true]],
        generate_execution_log: true
      ]

      assert %Beam{
               id: id,
               name: name,
               description: description,
               input_schema: input_schema,
               generate_execution_log: generate_execution_log
             } = Beam.new(attrs)

      assert id == "test-1"
      assert name == "Test Beam"
      assert description == "A test beam"
      assert input_schema == [value: [type: :string, required: true]]
      assert generate_execution_log == true
    end

    test "sets default values" do
      beam = Beam.new([])

      assert %Beam{
               timeout: timeout,
               generate_execution_log: generate_execution_log
             } = beam

      assert timeout == :timer.minutes(5)
      assert generate_execution_log == false
    end
  end

  describe "when using Beam" do
    test "defines a beam module with correct attributes" do
      assert %Beam{
               name: "Test Beam",
               description: "A test beam",
               input_schema: %{
                 type: :object,
                 properties: %{value: %{type: :string}},
                 required: ["value"]
               },
               output_schema: %{
                 type: :object,
                 properties: %{trade_id: %{type: :string}},
                 required: ["trade_id"]
               }
             } = TestBeam.view()
    end

    test "serializes step definitions" do
      steps = TestBeam.__steps__()

      assert {:sequence,
              [
                %{id: :first, module: TestPrism},
                %{id: :first_again, module: TestPrism},
                {:parallel,
                 [
                   %{id: :second, opts: %{retries: 2}},
                   %{id: :third, opts: %{store_io: true}}
                 ]},
                {:branch, {TestBeam, :above_threshold?}, _branches}
              ]} = steps
    end

    test "supports parameter references" do
      steps = TestBeam.__steps__()

      assert {:sequence,
              [
                %{id: :first, module: TestPrism},
                %{id: :first_again, module: TestPrism},
                {:parallel,
                 [
                   %{
                     id: :second,
                     module: TestPrism,
                     opts: %{
                       timeout: 300_000,
                       fallback: nil,
                       dependencies: [],
                       retries: 2,
                       store_io: false,
                       retry_backoff: 1000,
                       track: false
                     },
                     params: %{value: "fixed"}
                   },
                   %{
                     id: :third,
                     module: TestPrism,
                     opts: %{
                       timeout: 300_000,
                       fallback: nil,
                       dependencies: [],
                       retries: 0,
                       store_io: true,
                       retry_backoff: 1000,
                       track: false
                     },
                     params: %{value: [:steps, :first, :result]}
                   }
                 ]},
                {:branch, {Lux.BeamTest.TestBeam, :above_threshold?},
                 [
                   true: %{
                     id: :high,
                     module: TestPrism,
                     opts: %{
                       timeout: 300_000,
                       fallback: nil,
                       dependencies: [],
                       retries: 0,
                       store_io: false,
                       retry_backoff: 1000,
                       track: false
                     },
                     params: %{value: "high"}
                   },
                   false: %{
                     id: :low,
                     module: TestPrism,
                     opts: %{
                       timeout: 300_000,
                       fallback: nil,
                       dependencies: [],
                       retries: 0,
                       store_io: false,
                       retry_backoff: 1000,
                       track: false
                     },
                     params: %{value: "low"}
                   }
                 ]}
              ]} = steps
    end
  end

  describe "serialization" do
    test "beam can be serialized and deserialized" do
      beam = TestBeam.view()
      binary = :erlang.term_to_binary(beam)
      deserialized = :erlang.binary_to_term(binary)

      assert beam == deserialized
    end

    test "step definitions can be serialized and deserialized" do
      steps = TestBeam.__steps__()
      binary = :erlang.term_to_binary(steps)
      deserialized = :erlang.binary_to_term(binary)

      assert steps == deserialized
    end
  end

  describe "step validation" do
    test "validates step IDs are of the same type of what we define them as" do
      steps = TestBeam.__steps__()

      assert {:sequence, [first | _rest]} = steps
      assert :first = first.id
    end

    test "validates step options have correct defaults" do
      steps = TestBeam.__steps__()
      {:sequence, [first | _]} = steps

      assert %{opts: opts} = first
      assert opts.timeout == :timer.minutes(5)
      assert opts.retries == 0
      assert opts.retry_backoff == 1000
      assert opts.track == false
      assert opts.dependencies == []
      assert opts.store_io == false
    end

    test "validates step parameters are properly referenced" do
      steps = TestBeam.__steps__()
      {:sequence, [first | _]} = steps

      assert %{params: %{value: :value}} = first
    end
  end

  describe "branch validation" do
    test "validates branch condition is properly serialized" do
      steps = TestBeam.__steps__()
      {:sequence, steps_list} = steps
      branch = List.last(steps_list)

      assert {:branch, {TestBeam, :above_threshold?}, branches} = branch
      assert is_list(branches)
      assert Keyword.has_key?(branches, true)
      assert Keyword.has_key?(branches, false)
    end

    test "validates branch steps have correct structure" do
      steps = TestBeam.__steps__()
      {:sequence, steps_list} = steps
      {:branch, _, branches} = List.last(steps_list)

      high_step = branches[true]
      low_step = branches[false]

      assert high_step.id == :high
      assert high_step.params.value == "high"
      assert low_step.id == :low
      assert low_step.params.value == "low"
    end
  end

  defmodule TestPrism do
    @moduledoc false
    use Lux.Prism

    def handler(%{fail: true}, _ctx), do: {:error, "Intentional failure"}

    def handler(%{fail: :unrecoverable}, _ctx),
      do: {:error, %{type: :unrecoverable, message: "Cannot recover"}}

    def handler(%{fail: :recoverable}, _ctx),
      do: {:error, %{type: :recoverable, message: "Can recover"}}

    def handler(input, _ctx), do: {:ok, input}
  end

  defmodule TestFallback do
    @moduledoc false
    def handle_error(%{error: %{type: :recoverable} = error}) do
      {:continue, %{recovered: true, original_error: error}}
    end

    def handle_error(%{error: error}) do
      {:stop, "Stopped by fallback: #{inspect(error)}"}
    end
  end

  describe "fallbacks" do
    test "handles module-level fallbacks" do
      defmodule ModuleFallbackBeam do
        @moduledoc false
        use Lux.Beam

        sequence do
          step(:test, TestPrism, %{fail: :recoverable}, fallback: TestFallback)
        end
      end

      {:ok, result, _log} = ModuleFallbackBeam.run(%{})
      assert result.recovered == true
      assert result.original_error.type == :recoverable
    end

    test "module fallback can stop execution" do
      defmodule ModuleFallbackStopBeam do
        @moduledoc false
        use Lux.Beam

        sequence do
          step(:test, TestPrism, %{fail: :unrecoverable}, fallback: TestFallback)
        end
      end

      {:error, message, _log} = ModuleFallbackStopBeam.run(%{})
      assert message =~ "Stopped by fallback"
    end

    test "handles inline fallbacks with continue" do
      defmodule InlineFallbackBeam do
        @moduledoc false
        use Lux.Beam

        sequence do
          step(:test, TestPrism, %{fail: true},
            fallback: fn %{error: error, context: _ctx} ->
              {:continue, %{handled: true, error: error}}
            end
          )
        end
      end

      {:ok, result, _log} = InlineFallbackBeam.run(%{})
      assert result.handled == true
      assert result.error == "Intentional failure"
    end

    test "inline fallback can stop execution" do
      defmodule InlineFallbackStopBeam do
        @moduledoc false
        use Lux.Beam

        sequence do
          step(:test, TestPrism, %{fail: true},
            fallback: fn %{error: _error, context: _ctx} ->
              {:stop, "Stopped by inline fallback"}
            end
          )
        end
      end

      {:error, message, _log} = InlineFallbackStopBeam.run(%{})
      assert message == "Stopped by inline fallback"
    end

    test "fallback has access to context" do
      defmodule ContextFallbackBeam do
        @moduledoc false
        use Lux.Beam

        sequence do
          step(:first, TestPrism, %{value: 123})

          step(:second, TestPrism, %{fail: true},
            fallback: fn %{context: ctx} ->
              {:continue, %{previous_value: ctx[:steps][:first][:result].value}}
            end
          )
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
