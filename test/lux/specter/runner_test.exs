defmodule Lux.Specter.RunnerTest do
  use ExUnit.Case, async: true
  alias Lux.Specter.Runner

  # Test modules
  defmodule TestAgent do
    use Lux.Specter

    def new do
      Lux.Specter.new(%{name: "Test Specter", module: __MODULE__})
    end
  end

  defmodule TestPrism do
    use Lux.Prism,
      name: "Test Prism",
      description: "A test prism"

    def handler(_params, _context), do: {:ok, %{result: "test"}}
  end

  defmodule TestBeam do
    use Lux.Beam,
      name: "Test Beam",
      description: "A test beam"

    def steps do
      sequence do
        step(:test, TestPrism, %{})
      end
    end
  end

  describe "start_link/1" do
    test "starts runner process" do
      specter = Lux.Specter.new(%{name: "Test Specter"})
      assert {:ok, pid} = Runner.start_link(specter)
      assert Process.alive?(pid)
    end
  end

  describe "get_specter/1" do
    setup do
      specter = Lux.Specter.new(%{name: "Test Specter"})
      {:ok, pid} = Runner.start_link(specter)
      {:ok, pid: pid, specter: specter}
    end

    test "returns current specter state", %{pid: pid, specter: specter} do
      assert {:ok, ^specter, ^pid} = Runner.get_specter(pid)
    end
  end

  describe "get_state/1" do
    setup do
      specter = Lux.Specter.new(%{name: "Test Specter"})
      {:ok, pid} = Runner.start_link(specter)
      {:ok, pid: pid, specter: specter}
    end

    test "returns runner state", %{pid: pid, specter: specter} do
      assert {:ok, %{specter: ^specter, context: context}} = Runner.get_state(pid)
      assert is_map(context)
    end
  end

  describe "schedule_beam/4" do
    setup do
      specter = Lux.Specter.new(%{name: "Test Specter"})
      {:ok, pid} = Runner.start_link(specter)
      {:ok, pid: pid}
    end

    test "schedules a beam", %{pid: pid} do
      assert :ok = Runner.schedule_beam(pid, TestBeam, "*/5 * * * *")
      {:ok, specter, _} = Runner.get_specter(pid)
      assert length(specter.scheduled_beams) == 1
    end

    test "handles invalid cron expression", %{pid: pid} do
      assert {:error, _} = Runner.schedule_beam(pid, TestBeam, "invalid")
    end
  end

  describe "unschedule_beam/2" do
    setup do
      specter = Lux.Specter.new(%{name: "Test Specter"})
      {:ok, pid} = Runner.start_link(specter)
      :ok = Runner.schedule_beam(pid, TestBeam, "*/5 * * * *")
      {:ok, pid: pid}
    end

    test "removes scheduled beam", %{pid: pid} do
      assert :ok = Runner.unschedule_beam(pid, TestBeam)
      {:ok, specter, _} = Runner.get_specter(pid)
      assert specter.scheduled_beams == []
    end
  end

  describe "handle_signal/2" do
    setup do
      specter = TestAgent.new()
      {:ok, pid} = start_supervised({Runner, specter})
      {:ok, pid: pid}
    end

    test "processes signal", %{pid: pid} do
      :erlang.trace(pid, true, [:receive])

      signal = %Lux.Signal{schema_id: TestSignalSchema, payload: %{}}
      Runner.handle_signal(pid, signal)

      assert_receive {:trace, ^pid, :receive, {_, {:handle_signal, received_signal}}}, 5000

      assert received_signal == signal
      assert Process.alive?(pid)
    end
  end

  describe "trigger_learning/1" do
    setup do
      specter = Lux.Specter.new(%{name: "Test Specter"})
      {:ok, pid} = Runner.start_link(specter)
      {:ok, pid: pid, original_specter: specter}
    end

    test "triggers learning process", %{pid: pid, original_specter: original_specter} do
      Runner.trigger_learning(pid)
      # Wait a bit for async operation
      Process.sleep(100)
      {:ok, updated_specter, _} = Runner.get_specter(pid)
      refute updated_specter.reflection == original_specter.reflection
    end
  end

  describe "periodic tasks" do
    setup do
      # Use shorter intervals for testing
      specter =
        Lux.Specter.new(%{
          name: "Test Specter",
          reflection_interval: 100
        })

      {:ok, pid} = Runner.start_link(specter)
      {:ok, pid: pid, original_specter: specter}
    end

    test "executes scheduled beams", %{pid: pid} do
      # Schedule a beam to run every minute
      :ok = Runner.schedule_beam(pid, TestBeam, "* * * * *")
      # Wait for beam check
      Process.sleep(100)
      assert Process.alive?(pid)
    end
  end

  describe "error handling" do
    setup do
      specter = Lux.Specter.new(%{name: "Test Specter"})
      {:ok, pid} = Runner.start_link(specter)
      {:ok, pid: pid}
    end

    test "survives reflection errors", %{pid: pid} do
      # Force an error by sending invalid context
      send(pid, :reflect)
      Process.sleep(100)
      assert Process.alive?(pid)
    end

    test "survives beam execution errors", %{pid: pid} do
      # Schedule a beam that will fail
      :ok = Runner.schedule_beam(pid, TestBeam, "* * * * *", fail: true)
      send(pid, :check_beams)
      Process.sleep(100)
      assert Process.alive?(pid)
    end
  end
end
