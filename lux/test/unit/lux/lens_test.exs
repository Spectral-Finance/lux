defmodule Lux.LensTest do
  use UnitAPICase, async: true

  alias Lux.Lens

  setup do
    Req.Test.verify_on_exit!()
  end

  describe "new" do
    test "creates a new lens from a map" do
      assert %Lens{
               url: "https://weatherapi.com",
               method: :get,
               params: %{id: 1},
               name: "weather",
               headers: [],
               auth: nil,
               description: "",
               schema: %{}
             } =
               Lux.Lens.new(
                 url: "https://weatherapi.com",
                 method: :get,
                 params: %{id: 1},
                 name: "weather"
               )
    end

    test "creates a new lens from a list" do
      assert %Lens{
               url: "https://weatherapi.com",
               method: :get,
               params: %{id: 1},
               name: "",
               headers: [],
               auth: nil,
               description: "",
               schema: %{}
             } = Lens.new(url: "https://weatherapi.com", method: :get, params: %{id: 1})
    end
  end

  describe "When we `use` a Lens" do
    test "creates a lens with declarative attributes" do
      defmodule WeatherLens do
        @moduledoc false
        use Lux.Lens,
          name: "Weather API",
          description: "Fetches weather data",
          url: "https://api.weatherapi.com/v1/current.json",
          method: :get,
          params: %{key: "default_key"},
          headers: [{"Accept", "application/json"}],
          schema: %{
            type: :object,
            properties: %{
              location: %{type: :string, description: "City name"},
              units: %{type: :string, description: "Temperature units"}
            }
          }

        def after_focus(%{"current" => %{"temp_c" => temp}} = body) do
          {:ok, %{temperature: temp, raw_data: body}}
        end
      end

      lens = WeatherLens.view()

      assert %Lens{} = lens
      assert lens.name == "Weather API"
      assert lens.description == "Fetches weather data"
      assert lens.url == "https://api.weatherapi.com/v1/current.json"
      assert lens.method == :get
      assert lens.params == %{key: "default_key"}
      assert lens.headers == [{"Accept", "application/json"}]

      assert lens.schema == %{
               type: :object,
               properties: %{
                 location: %{type: :string, description: "City name"},
                 units: %{type: :string, description: "Temperature units"}
               }
             }

      assert is_function(lens.after_focus, 1)
    end

    test "uses module name as default name" do
      defmodule DefaultNameLens do
        @moduledoc false
        use Lux.Lens,
          url: "https://api.example.com"
      end

      lens = DefaultNameLens.view()
      assert lens.name == "Lux.LensTest.DefaultNameLens"
    end

    test "supports focus with input params" do
      defmodule TestLens do
        @moduledoc false
        use Lux.Lens,
          url: "https://api.example.com",
          method: :get,
          params: %{api_key: "secret"}

        def after_focus(%{"temp" => temp}) do
          {:ok, %{"temp" => temp}}
        end
      end

      Req.Test.expect(Lux.Lens, fn conn ->
        assert conn.params == %{"api_key" => "secret", "city" => "London"}
        Req.Test.json(conn, %{"temp" => 20})
      end)

      assert {:ok, %{"temp" => 20}} = TestLens.focus(%{city: "London"})
    end

    test "supports custom after_focus transformation" do
      defmodule TransformLens do
        @moduledoc false
        use Lux.Lens,
          url: "https://api.example.com"

        def after_focus(%{"temp" => temp}) do
          {:ok, %{temperature: temp, unit: "C"}}
        end
      end

      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"temp" => 25})
      end)

      assert {:ok, %{temperature: 25, unit: "C"}} =
               TransformLens.focus(%{}, with_after_focus: true)
    end

    test "works without after_focus function" do
      defmodule BasicLens do
        @moduledoc false
        use Lux.Lens,
          url: "https://api.example.com"

        def after_focus(body) do
          {:ok, body}
        end
      end

      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"temp" => 25})
      end)

      assert {:ok, %{"temp" => 25}} = BasicLens.focus(%{}, with_after_focus: false)
    end

    test "handles authentication" do
      defmodule AuthLens do
        @moduledoc false
        use Lux.Lens,
          url: "https://api.example.com",
          auth: %{type: :api_key, key: "secret-key"}
      end

      lens = AuthLens.view()
      authenticated_lens = Lens.authenticate(lens)

      assert authenticated_lens.headers == [{"Authorization", "Bearer secret-key"}]
    end
  end

  describe "focus" do
    test "returns the body on status 200" do
      Req.Test.expect(Lux.Lens, fn conn ->
        Req.Test.json(conn, %{"celcius" => -15})
      end)

      lens = Lens.new(url: "https://weatherapi.com", method: :get)
      assert {:ok, %{"celcius" => -15}} = Lens.focus(lens)
    end
  end

  describe "authenticate" do
    test "adds api key auth header" do
      lens =
        Lens.new(
          url: "https://api.example.com",
          auth: %{type: :api_key, key: "secret-key"}
        )

      assert %Lens{headers: [{"Authorization", "Bearer secret-key"}]} = Lens.authenticate(lens)
    end

    test "adds basic auth header" do
      lens =
        Lens.new(
          url: "https://api.example.com",
          auth: %{type: :basic, username: "user", password: "pass"}
        )

      assert %Lens{headers: [{"Authorization", "Basic " <> _}]} = Lens.authenticate(lens)
    end

    test "adds oauth token header" do
      lens =
        Lens.new(
          url: "https://api.example.com",
          auth: %{type: :oauth, token: "oauth-token"}
        )

      assert %Lens{headers: [{"Authorization", "Bearer oauth-token"}]} = Lens.authenticate(lens)
    end

    test "calls custom auth function" do
      custom_auth = fn lens ->
        %Lens{lens | headers: [{"X-Custom-Auth", "custom-value"}]}
      end

      lens =
        Lens.new(
          url: "https://api.example.com",
          auth: %{type: :custom, auth_function: custom_auth}
        )

      assert %Lens{headers: [{"X-Custom-Auth", "custom-value"}]} = Lens.authenticate(lens)
    end
  end
end
