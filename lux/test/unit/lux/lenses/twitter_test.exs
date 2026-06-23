defmodule Lux.Lenses.TwitterTest do
  use ExUnit.Case, async: true

  test "defines Twitter namespace and structs" do
    assert %Lux.Lens.Twitter{} = %Lux.Lens.Twitter{}
    assert %Lux.Lens.Twitter.Profile{} = %Lux.Lens.Twitter.Profile{}
    assert %Lux.Lens.Twitter.Tweet{} = %Lux.Lens.Twitter.Tweet{}
  end
end
