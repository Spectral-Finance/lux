defmodule Lux.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Lux.Factory
    end
  end
end
