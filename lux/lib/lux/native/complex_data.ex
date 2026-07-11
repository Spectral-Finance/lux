defmodule Lux.Native.ComplexData do
  @moduledoc """
  A complex struct mapped exactly to the Rust `ComplexData` NIF struct.
  """
  defstruct [:name, :items, :metadata]

  @type t :: %__MODULE__{
          name: String.t(),
          items: list(String.t()),
          metadata: map()
        }
end
