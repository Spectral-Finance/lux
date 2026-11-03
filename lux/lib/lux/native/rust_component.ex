defmodule Lux.Native.RustComponent do
  @moduledoc """
  Behaviour and macro for defining high-performance Lux Prisms and Beams in Rust (#103).
  """

  @callback component_name() :: String.t()
  @callback invoke_native(map()) :: {:ok, map()} | {:error, term()}

  defmacro __using__(opts) do
    name = Keyword.fetch!(opts, :name)

    quote do
      @behaviour Lux.Native.RustComponent

      @impl true
      def component_name, do: unquote(name)

      def run(input) when is_map(input) do
        start_time = System.monotonic_time(:microsecond)
        result = invoke_native(input)
        elapsed_us = System.monotonic_time(:microsecond) - start_time
        {:ok, %{component: component_name(), elapsed_us: elapsed_us, result: result}}
      end
    end
  end
end
