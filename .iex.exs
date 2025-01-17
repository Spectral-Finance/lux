defmodule IexHelpers do
  @moduledoc """
  Helper functions for debugging and inspecting the system in IEx.
  """

  alias Lux.Engine.Router.DeliverySupervisor

  def start_observer do
    Mix.ensure_application!(:wx)
    Mix.ensure_application!(:runtime_tools)
    Mix.ensure_application!(:observer)

    :observer.start()
  end

  @doc """
  Lists all registered specters.
  """
  def list_specters do
    Registry.select(Lux.Engine.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
    |> Enum.filter(&(to_string(&1) =~ ~r/^specter/))
    |> Enum.sort()
  end

  @doc """
  Lists all delivery managers in the pool.
  """
  def list_delivery_managers do
    Registry.select(Lux.Engine.Registry, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.filter(fn {name, _} -> to_string(name) =~ ~r/^delivery_manager/ end)
    |> Enum.sort()
  end

  @doc """
  Gets process info for a specter by ID.
  """
  def inspect_specter(specter_id) do
    case Registry.lookup(Lux.Engine.Registry, specter_id) do
      [{pid, _}] -> Process.info(pid)
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Gets the current state of a specter by ID.
  """
  def get_specter_state(specter_id) do
    case Registry.lookup(Lux.Engine.Registry, specter_id) do
      [{pid, _}] -> :sys.get_state(pid)
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Gets process info for a delivery manager by index.
  """
  def inspect_delivery_manager(index) when is_integer(index) do
    name = :"delivery_manager_#{index}"
    case Registry.lookup(Lux.Engine.Registry, name) do
      [{pid, _}] -> Process.info(pid)
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Gets the current state of a delivery manager by index.
  """
  def get_delivery_manager_state(index) when is_integer(index) do
    name = :"delivery_manager_#{index}"
    case Registry.lookup(Lux.Engine.Registry, name) do
      [{pid, _}] -> :sys.get_state(pid)
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Prints system statistics including:
  - Number of specters
  - Number of delivery managers
  - Process memory usage
  """
  def system_stats do
    specters = list_specters()
    delivery_managers = list_delivery_managers()

    IO.puts """
    System Statistics
    ----------------
    Specters: #{length(specters)}
    Delivery Managers: #{length(delivery_managers)}
    Memory Usage: #{format_bytes(:erlang.memory(:total))}
    Process Count: #{length(Process.list())}
    """
  end

  @doc """
  Sends a test signal to a specter.
  """
  def send_test_signal(specter_id, type \\ "test.event") do
    signal = %{
      type: type,
      data: %{test: true, timestamp: DateTime.utc_now()},
      metadata: %{source: "iex_helper"}
    }

    name = DeliverySupervisor.get_delivery_manager()
    DeliverySupervisor.deliver(name, signal, specter_id)
  end

  # Private helpers

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes > 1_000_000_000 -> "#{Float.round(bytes / 1_000_000_000, 2)} GB"
      bytes > 1_000_000 -> "#{Float.round(bytes / 1_000_000, 2)} MB"
      bytes > 1_000 -> "#{Float.round(bytes / 1_000, 2)} KB"
      true -> "#{bytes} B"
    end
  end
end

# Import helpers into IEx session
import IexHelpers
