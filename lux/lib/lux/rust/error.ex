defmodule Lux.Rust.Error do
  @moduledoc """
  Structured error type for Lux Rust integration.

  Errors from the Rust core are categorized by kind, allowing Elixir code
  to handle different error types appropriately.

  ## Fields

    * `:kind` - The error category (`:type_error`, `:runtime_error`, `:ffi_error`, `:not_found`, `:unknown`)
    * `:message` - Human-readable error description
    * `:context` - Optional execution context or stack trace
    * `:source` - Optional source error for chaining

  ## Examples

      %Lux.Rust.Error{
        kind: :type_error,
        message: "cannot add string and integer"
      }
  """

  use Lux.Types

  @type t() :: %__MODULE__{
          kind: atom(),
          message: String.t(),
          context: nullable(String.t()),
          source: nullable(String.t())
        }

  @type kind :: :type_error | :runtime_error | :ffi_error | :not_found | :unknown

  defstruct kind: :unknown,
            message: "",
            context: nil,
            source: nil

  @doc """
  Creates a new error with the given kind and message.
  """
  @spec new(kind(), String.t()) :: t()
  def new(kind, message) do
    %__MODULE__{kind: kind, message: message}
  end

  @doc """
  Creates a new error from a string message. Defaults to `:runtime_error` kind.
  """
  @spec from_string(String.t()) :: t()
  def from_string(message) do
    %__MODULE__{kind: :runtime_error, message: message}
  end

  @impl true
  def exception(props) when is_list(props) do
    kind = Keyword.get(props, :kind, :unknown)
    message = Keyword.get(props, :message, "Rust error")
    %__MODULE__{kind: kind, message: to_string(message)}
  end

  def exception(%__MODULE__{} = error), do: error

  def exception(other) do
    %__MODULE__{
      kind: :unknown,
      message: "Rust error: #{inspect(other)}"
    }
  end

  @impl true
  def message(%__MODULE__{kind: kind, message: msg}) do
    "[#{kind}] #{msg}"
  end

  @impl true
  def format_message(%__MODULE__{kind: kind, message: msg, context: ctx}) do
    base = "[#{kind}] #{msg}"
    if ctx, do: base <> " (context: #{ctx})", else: base
  end
end

defimpl String.Chars, for: Lux.Rust.Error do
  def to_string(%{kind: kind, message: msg}) do
    "#{kind}: #{msg}"
  end
end
