defmodule Lux.TypeSystem do
  @moduledoc """
  Advanced type mapping between Elixir and Rust.
  Provides custom type definitions, struct and enum support,
  and Serde integration for bidirectional serialization.
  """

  # We use the Rustler macro to load our NIFs.
  # The :crate option corresponds to the name of the rustler project in native/
  use Rustler, otp_app: :lux, crate: "lux_types"

  @doc """
  Serializes a ComplexStruct to a JSON string using Rust's Serde.
  """
  def serialize_to_json(_struct_data), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Deserializes a JSON string into a ComplexStruct using Rust's Serde.
  Returns {:ok, struct} or {:error, reason}.
  """
  def deserialize_from_json(_json_str), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Processes a ComplexStruct in Rust, modifying its internal state.
  """
  def process_complex_type(_struct_data), do: :erlang.nif_error(:nif_not_loaded)
end

defmodule Lux.TypeSystem.ComplexStruct do
  @moduledoc """
  A complex struct that maps directly to Rust's ComplexStruct.
  Includes a nested enum (:String, :Integer, :Boolean, :Float, :List, :Map, :Custom).
  """
  defstruct [:id, :name, :type_def, :metadata, :is_active]

  @type t :: %__MODULE__{
          id: integer(),
          name: String.t(),
          type_def: atom(),
          metadata: String.t(),
          is_active: boolean()
        }
end
