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