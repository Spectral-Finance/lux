defmodule LuxTest do
  use UnitCase

  doctest Lux

  defmodule TestBeam do
    @moduledoc false
    use Lux.Beam

    sequence do
      step :step1, Step, [:input]
    end
  end

  defmodule TestPrism do
    @moduledoc false
    use Lux.Prism

    def handler(_input, _context) do
      {:ok, %{message: "Hello, world!"}}
    end
  end

  defmodule TestLens do
    @moduledoc false
    use Lux.Lens
  end

  test "greets the world" do
    assert Lux.hello() == :world
  end

  test "checks if a module is a beam" do
    assert Lux.beam?(Lux) == false
    assert Lux.beam?(TestBeam) == true
  end

  test "checks if a module is a prism" do
    assert Lux.prism?(Lux) == false
    assert Lux.prism?(TestPrism) == true
  end

  test "checks if a module is a lens" do
    assert Lux.lens?(Lux) == false
    assert Lux.lens?(TestLens) == true
  end
end
