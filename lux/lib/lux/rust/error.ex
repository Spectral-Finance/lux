defmodule Lux.Rust.Error do
  @moduledoc """
  Represents structured errors returned from the Rust core runtime.
  """

  defexception [:type, :message, :details]

  @type t :: %__MODULE__{
          type: atom(),
          message: String.t(),
          details: map()
        }

  @impl true
  def message(%__MODULE__{type: type, message: message}) do
    "[RustError:#{type}] #{message}"
  end

  @doc """
  Builds a new `%Lux.Rust.Error{}` from a raw error map or tuple.
  """
  def from_raw(%{"type" => type, "message" => msg} = raw) do
    %__MODULE__{
      type: parse_type(type),
      message: msg,
      details: Map.delete(raw, "message")
    }
  end

  def from_raw(msg) when is_binary(msg) do
    %__MODULE__{
      type: :runtime_error,
      message: msg,
      details: %{}
    }
  end

  def from_raw(other) do
    %__MODULE__{
      type: :unknown_error,
      message: inspect(other),
      details: %{}
    }
  end

  defp parse_type("TypeConversion"), do: :type_conversion
  defp parse_type("Execution"), do: :execution
  defp parse_type("FunctionNotFound"), do: :function_not_found
  defp parse_type("InvalidArgument"), do: :invalid_argument
  defp parse_type("Panic"), do: :panic
  defp parse_type("Io"), do: :io
  defp parse_type("Serialization"), do: :serialization
  defp parse_type(other) when is_binary(other) do
    other |> Macro.underscore() |> String.to_atom()
  end
  defp parse_type(_), do: :runtime_error
end
