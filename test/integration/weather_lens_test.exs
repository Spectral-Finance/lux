defmodule Lux.Integration.WeatherLensTest do
  @moduledoc false
  use IntegrationCase, async: true

  defmodule WeatherLens do
    @moduledoc """
    Just a sanity check to make sure lenses do work.
    Also acts as an example of using custom auth
    """
    use Lux.Lens,
      name: "OpenWeather API",
      description: "Fetches weather data from OpenWeather",
      url: "https://api.openweathermap.org/data/2.5/weather",
      method: :get,
      auth: %{type: :custom, auth_function: &__MODULE__.add_appid_to_request/1},
      schema: %{
        type: :object,
        properties: %{
          q: %{
            type: :string,
            description: "City name"
          },
          units: %{
            type: :string,
            description:
              "Temperature units. For temperature in Fahrenheit use units=imperial and for temperature in Celsius use units=metric",
            enum: ["metric", "imperial"]
          }
        },
        required: ["q"]
      }

    def after_focus(%{"main" => %{"temp" => temp}} = body) do
      {:ok, %{temperature: temp, raw_data: body}}
    end

    def after_focus(%{"error" => error}) do
      {:error, error}
    end

    def add_appid_to_request(lens) do
      %{
        lens
        | params:
            Map.put(
              lens.params,
              "appid",
              Application.get_env(:lux, :api_keys)[:integration_openweather]
            )
      }
    end
  end

  defmodule NoAuthWeatherLens do
    @moduledoc """
    Going to call the api without auth so that we always fail
    """
    use Lux.Lens,
      name: "OpenWeather API",
      description: "Fetches weather data from OpenWeather",
      url: "https://api.openweathermap.org/data/2.5/weather",
      method: :get
  end

  test "can fetch weather data from OpenWeather API" do
    assert {:ok, %{temperature: temp}} = WeatherLens.focus(%{q: "London", units: "metric"})
    assert is_number(temp)
  end

  test "fails when no auth is provided" do
    assert {:error,
            %{
              "cod" => 401,
              "message" => "Invalid API key." <> _
            }} = NoAuthWeatherLens.focus()
  end
end
