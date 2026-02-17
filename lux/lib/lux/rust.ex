defmodule Lux.Rust do
  @moduledoc """
  Module for Rust-compatible types and conversion API.
  """

  defstruct [:value]

  def new(value) do
    %__MODULE__{value: value}
  end

  def to_rust(%__MODULE__{value: value}) do
    # Convert Elixir value to Rust-compatible format
    :erlang.nif_call(:rust_nifs, :to_rust, [value])
  end

  def from_rust(rust_value) do
    # Convert Rust-compatible value to Elixir format
    :erlang.nif_call(:rust_nifs, :from_rust, [rust_value])
  end
end

defmacro deftype(name, fields) do
  quote bind_quoted: [name: name, fields: fields] do
    defmodule unquote(name) do
      @moduledoc "Rust-compatible struct"

      defstruct unquote(fields)

      def new(unquote_splicing(Enum.map(fields, fn field -> :"#{field}" end))) do
        %__MODULE__{unquote_splicing(Enum.map(fields, fn field -> {:"#{field}", var!(:"#{field}")} end))}
      end

      Enum.each(fields, fn field ->
        quote do
          def unquote(:"to_rust_#{field})(%unquote(name){unquote(field): value}) do
            :erlang.nif_call(:rust_nifs, :to_rust_#{field}, [value])
          end

          def unquote(:"from_rust_#{field})(rust_value) do
            :erlang.nif_call(:rust_nifs, :from_rust_#{field}, [rust_value])
          end
        end
      end)
    end
  end
end

def elixir_to_rust(nil), do: "None"
def elixir_to_rust(true), do: "true"
def elixir_to_rust(false), do: "false"
def elixir_to_rust(integer) when is_integer(integer), do: to_string(integer)
def elixir_to_rust(float) when is_float(float), do: Float.to_string(float)
def elixir_to_rust(string) when is_binary(string), do: string
def elixir_to_rust(list) when is_list(list), do: Enum.map(list, &elixir_to_rust/1)
def elixir_to_rust(map) when is_map(map), do: Enum.into(Enum.map(map, fn {k, v} -> {elixir_to_rust(k), elixir_to_rust(v)} end), %{})

def rust_to_elixir(nil), do: nil
def rust_to_elixir(true), do: true
def rust_to_elixir(false), do: false
def rust_to_elixir(integer) when is_integer(integer), do: integer
def rust_to_elixir(float) when is_float(float), do: float
def rust_to_elixir(string) when is_binary(string), do: string
def rust_to_elixir(list) when is_list(list), do: Enum.map(list, &rust_to_elixir/1)
def rust_to_elixir(map) when is_map(map), do: Enum.into(Enum.map(map, fn {k, v} -> {rust_to_elixir(k), rust_to_elixir(v)} end), %{})

# Lines 1-65 of lux/lib/lux/rust.ex
defmodule Lux.Rust do
  @moduledoc """
  Module for Rust-compatible types and conversion API.
  """

  defstruct [:value]

  def new(value) do
    %__MODULE__{value: value}
  end

  def to_rust(%__MODULE__{value: value}) do
    # Convert Elixir value to Rust-compatible format
    :erlang.nif_call(:rust_nifs, :to_rust, [value])
  end

  def from_rust(rust_value) do
    # Convert Rust-compatible value to Elixir format
    :erlang.nif_call(:rust_nifs, :from_rust, [rust_value])
  end
end

defmacro deftype(name, fields) do
  quote bind_quoted: [name: name, fields: fields] do
    defmodule unquote(name) do
      @moduledoc "Rust-compatible struct"

      defstruct unquote(fields)

      def new(unquote_splicing(Enum.map(fields, fn field -> :"#{field}" end))) do
        %__MODULE__{unquote_splicing(Enum.map(fields, fn field -> {:"#{field}", var!(:"#{field}")} end))}
      end

      Enum.each(fields, fn field ->
        quote do
          def unquote(:"to_rust_#{field})(%unquote(name){unquote(field): value}) do
            :erlang.nif_call(:rust_nifs, :to_rust_#{field}, [value])
          end

          def unquote(:"from_rust_#{field})(rust_value) do
            :erlang.nif_call(:rust_nifs, :from_rust_#{field}, [rust_value])
          end
        end
      end)
    end
  end
end

def elixir_to_rust(nil), do: "None"
def elixir_to_rust(true), do: "true"
def elixir_to_rust(false), do: "false"
def elixir_to_rust(integer) when is_integer(integer), do: to_string(integer)
def elixir_to_rust(float) when is_float(float), do: Float.to_string(float)
def elixir_to_rust(string) when is_binary(string), do: string
def elixir_to_rust(list) when is_list(list), do: Enum.map(list, &elixir_to_rust/1)
def elixir_to_rust(map) when is_map(map), do: Enum.into(Enum.map(map, fn {k, v} -> {elixir_to_rust(k), elixir_to_rust(v)} end), %{})

def rust_to_elixir(nil), do: nil
def rust_to_elixir(true), do: true
def rust_to_elixir(false), do: false
def rust_to_elixir(integer) when is_integer(integer), do: integer
def rust_to_elixir(float) when is_float(float), do: float
def rust_to_elixir(string) when is_binary(string), do: string
def rust_to_elixir(list) when is_list(list), do: Enum.map(list, &rust_to_elixir/1)
def rust_to_elixir(map) when is_map(map), do: Enum.into(Enum.map(map, fn {k, v} -> {rust_to_elixir(k), rust_to_elixir(v)} end), %{})

<<<OLD>>>
# Lines 66-75 of lux/lib/lux/rust.ex
defmodule Lux.Rust do
  @moduledoc """
  Module for Rust-compatible types and conversion API.
  """

  defstruct [:value]

  def new(value) do
    %__MODULE__{value: value}
  end

  def to_rust(%__MODULE__{value: value}) do
    # Convert Elixir value to Rust-compatible format
    :erlang.nif_call(:rust_nifs, :to_rust, [value])
  end

  def from_rust(rust_value) do
    # Convert Rust-compatible value to Elixir format
    :erlang.nif_call(:rust_nifs, :from_rust, [rust_value])
  end
end
<<<NEW>>>
# Lines 66-75 of lux/lib/lux/rust.ex
defmodule Lux.Rust do
  @moduledoc """
  Module for Rust-compatible types and conversion API.
  """

  defstruct [:value]

  def new(value) do
    %__MODULE__{value: value}
  end

  def to_rust(%__MODULE__{value: value}) do
    # Convert Elixir value to Rust-compatible format
    :erlang.nif_call(:rust_nifs, :to_rust, [value])
  end

  def from_rust(rust_value) do
    # Convert Rust-compatible value to Elixir format
    :erlang.nif_call(:rust_nifs, :from_rust, [rust_value])
  end
end

# Lines 1-120 of lux/lib/lux/rust.ex
defmodule Lux.Rust do
  @moduledoc """
  Module for Rust-compatible types and conversion API.
  """

  defstruct [:value]

  def new(value) do
    %__MODULE__{value: value}
  end

  def to_rust(%__MODULE__{value: value}) do
    # Convert Elixir value to Rust-compatible format
    :erlang.nif_call(:rust_nifs, :to_rust, [value])
  end

  def from_rust(rust_value) do
    # Convert Rust-compatible value to Elixir format
    :erlang.nif_call(:rust_nifs, :from_rust, [rust_value])
  end
end

defmacro deftype(name, fields) do
  quote bind_quoted: [name: name, fields: fields] do
    defmodule unquote(name) do
      @moduledoc "Rust-compatible struct"

      defstruct unquote(fields)

      def new(unquote_splicing(Enum.map(fields, fn field -> :"#{field}" end))) do
        %__MODULE__{unquote_splicing(Enum.map(fields, fn field -> {:"#{field}", var!(:"#{field}")} end))}
      end

      Enum.each(fields, fn field ->
        quote do
          def unquote(:"to_rust_#{field})(%unquote(name){unquote(field): value}) do
            :erlang.nif_call(:rust_nifs, :to_rust_#{field}, [value])
          end

          def unquote(:"from_rust_#{field})(rust_value) do
            :erlang.nif_call(:rust_nifs, :from_rust_#{field}, [rust_value])
          end
        end
      end)
    end
  end
end

def elixir_to_rust(nil), do: "None"
def elixir_to_rust(true), do: "true"
def elixir_to_rust(false), do: "false"
def elixir_to_rust(integer) when is_integer(integer), do: to_string(integer)
def elixir_to_rust(float) when is_float(float), do: Float.to_string(float)
def elixir_to_rust(string) when is_binary(string), do: string
def elixir_to_rust(list) when is_list(list), do: Enum.map(list, &elixir_to_rust/1)
def elixir_to_rust(map) when is_map(map), do: Enum.into(Enum.map(map, fn {k, v} -> {elixir_to_rust(k), elixir_to_rust(v)} end), %{})

def rust_to_elixir(nil), do: nil
def rust_to_elixir(true), do: true
def rust_to_elixir(false), do: false
def rust_to_elixir(integer) when is_integer(integer), do: integer
def rust_to_elixir(float) when is_float(float), do: float
def rust_to_elixir(string) when is_binary(string), do: string
def rust_to_elixir(list) when is_list(list), do: Enum.map(list, &rust_to_elixir/1)
def rust_to_elixir(map) when is_map(map), do: Enum.into(Enum.map(map, fn {k, v} -> {rust_to_elixir(k), rust_to_elixir(v)} end), %{})

# Lines 1-65 of lux/lib/lux/rust.ex
defmodule Lux.Rust do
  @moduledoc """
  Module for Rust-compatible types and conversion API.
  """

  defstruct [:val

def elixir_to_rust(primitive) when is_integer(primitive), do: primitive
def elixir_to_rust(primitive) when is_float(primitive), do: primitive
def elixir_to_rust(primitive) when is_binary(primitive), do: primitive
def elixir_to_rust(primitive) when is_boolean(primitive), do: primitive
def elixir_to_rust(primitive) when is_nil(primitive), do: nil