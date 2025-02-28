defmodule Lux.Types do
  @moduledoc """
  Shared Types for Lux.
  """

  defmacro __using__(_opts) do
    quote do
      @typedoc """
      An optional type of a type `t` is a type that can be either the type `t` or `nil`.
      """
      @type nullable(t) :: t | nil
    end
  end
end
