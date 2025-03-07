defmodule Lux.PrismTest do
  use UnitCase, async: true

  alias Lux.Prism

  doctest Lux.Prism, import: true

  describe "new/1" do
    test "creates a prism from a variable map" do
      attrs = %{
        id: "1",
        name: "test",
        handler: fn -> :ok end,
        description: "test",
        examples: ["test"]
      }

      assert %Prism{
               name: name,
               id: id,
               handler: handler,
               description: description,
               examples: examples
             } = Prism.new(attrs)

      assert name == "test"
      assert id == "1"
      assert description == "test"
      assert examples == ["test"]
      assert is_function(handler)
    end

    test "creates a prism from a variable keyword list" do
      handler = fn -> :ok end

      attrs = [
        name: "test",
        id: "1",
        handler: handler
      ]

      assert %Prism{name: name, id: id, handler: handler} = Prism.new(attrs)

      assert name == "test"
      assert id == "1"
      assert is_function(handler)
    end
  end

  describe "When we `use` a Prism" do
    test "then we can call the `run` directly" do
      defmodule MyExclamationPrism do
        @moduledoc false
        use Lux.Prism

        def handler(input, _ctx) do
          {:ok, input <> "!!!"}
        end
      end

      assert MyExclamationPrism.run("Hello world") == {:ok, "Hello world!!!"}
    end

    test "creates a prism with declarative attributes" do
      defmodule WeatherPrism do
        @moduledoc false
        use Lux.Prism,
          name: "Weather Data",
          description: "Fetches weather data for a location",
          input_schema: %{
            type: :object,
            properties: %{
              location: %{type: :string, description: "City name"},
              units: %{type: :string, description: "Temperature units"}
            }
          },
          examples: ["London, C", "New York, F"]

        def handler(input, _ctx) do
          {:ok, %{temperature: 20, location: input.location, units: input.units}}
        end
      end

      prism = WeatherPrism.view()

      assert %Prism{} = prism
      assert prism.name == "Weather Data"
      assert prism.description == "Fetches weather data for a location"

      assert prism.input_schema == %{
               type: :object,
               properties: %{
                 location: %{type: :string, description: "City name"},
                 units: %{type: :string, description: "Temperature units"}
               }
             }

      assert prism.examples == ["London, C", "New York, F"]
      assert is_function(prism.handler, 2)

      # Test that the handler still works through the struct
      assert {:ok, result} = Prism.run(prism, %{location: "London", units: "C"}, nil)
      assert result.temperature == 20
      assert result.location == "London"
      assert result.units == "C"
    end

    test "uses module name as default name" do
      defmodule DefaultNamePrism do
        @moduledoc false
        use Lux.Prism

        def handler(_input, _ctx), do: {:ok, :done}
      end

      prism = DefaultNamePrism.view()
      assert prism.name == "Lux.PrismTest.DefaultNamePrism"
    end
  end

  describe "Work with python prism" do
    def get_test_prism(file) do
      __DIR__
      |> List.wrap()
      |> Enum.concat(["..", "..", "support", file])
      |> Path.join()
      |> Path.expand()
    end

    test "view/1" do
      prism_path = get_test_prism("simple_prism.py")

      assert {:error, :nofile} = Code.ensure_loaded(SimplePrism)

      prism = Prism.view(prism_path)
      assert %Prism{} = prism
      assert prism.name == "Simple Prism"
      assert prism.module_name == "SimplePrism"
      assert prism.description == "A very simple prism that greets you"

      assert {:module, SimplePrism} = Code.ensure_loaded(SimplePrism)
    end

    test "run/3" do
      prism_path = get_test_prism("simple_prism.py")

      assert {:ok, %{"success" => true, "data" => %{"message" => message}}} = Prism.run(prism_path, %{name: "John"}, nil)
      assert message == "Hello, John!"
    end
  end
end
