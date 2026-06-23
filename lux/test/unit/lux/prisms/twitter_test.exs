defmodule Lux.Prisms.TwitterTest do
  use ExUnit.Case, async: true

  test "defines Twitter prism namespace" do
    assert Code.ensure_loaded?(Lux.Prisms.Twitter)
  end
end
