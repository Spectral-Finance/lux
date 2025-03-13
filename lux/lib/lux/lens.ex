defmodule Lux.Lens do
  @moduledoc """
  Lenses are used to load data from a source and return it to the calling agent.

  ## Example

      defmodule MyApp.Lenses.WeatherLens do
        use Lux.Lens,
            name: "OpenWeather API",
            description: "Fetches weather data from OpenWeather",
            url: "https://api.openweathermap.org/data/2.5/weather",
            method: :get,
            schema: %{
              type: :object,
              properties: %{
                q: %{
                  type: :string,
                  description: "City name"
                },
                units: %{
                  type: :string,
                  description: "Temperature units. For temperature in Fahrenheit use units=imperial and for temperature in Celsius use units=metric",
                  enum: ["metric", "imperial"]
                },
                appid: %{type: :string, description: "API key"}
              },
              required: ["q", "appid"]
            }

        # Optional: Define a custom after_focus function
        def after_focus(%{"main" => %{"temp" => temp}} = body) do
          {:ok, %{temperature: temp, raw_data: body}}
        end

        def after_focus(%{"error" => error}) do
          {:error, error}
        end
      end
  """
  use Lux.Types

  defstruct after_focus: nil,
            name: nil,
            module_name: nil,
            url: nil,
            method: :get,
            params: %{},
            headers: [],
            auth: nil,
            description: "",
            schema: %{}

  @type t :: %__MODULE__{
          name: String.t(),
          module_name: String.t(),
          url: String.t(),
          method: atom(),
          params: map(),
          headers: list(),
          after_focus: (any() -> any()),
          auth: map(),
          description: String.t(),
          schema: map()
        }

  @optional_callbacks after_focus: 1

  defmacro __using__(opts) do
    quote do
      @behaviour Lux.Lens

      alias Lux.Lens

      # Register compile-time attributes
      Module.register_attribute(__MODULE__, :lens_struct, persist: false)
      Module.register_attribute(__MODULE__, :lens_module_name, persist: false)

      @lens_module_name __MODULE__ |> Module.split() |> Enum.join(".")

      # Create the struct at compile time
      @lens_struct Lux.Lens.new(
                     name: Keyword.get(unquote(opts), :name, @lens_module_name),
                     module_name: @lens_module_name,
                     description: Keyword.get(unquote(opts), :description, ""),
                     url: Keyword.get(unquote(opts), :url),
                     method: Keyword.get(unquote(opts), :method, :get),
                     params: Keyword.get(unquote(opts), :params, %{}),
                     headers: Keyword.get(unquote(opts), :headers, []),
                     auth: Keyword.get(unquote(opts), :auth),
                     schema: Keyword.get(unquote(opts), :schema, %{}),
                     after_focus: &__MODULE__.after_focus/1
                   )

      @doc """
      Returns the Lens struct for this module.
      """
      def view, do: @lens_struct

      @doc """
      Focuses the lens with the given input.
      """
      def focus(input \\ %{}, opts \\ []) do
        __MODULE__.view()
        |> Map.update!(:params, &Map.merge(&1, input))
        |> Lux.Lens.authenticate()
        |> Map.update!(:params, &before_focus(&1))
        |> Lux.Lens.focus(opts)
      end

      def after_focus(body), do: {:ok, body}
      def before_focus(params), do: params

      defoverridable after_focus: 1, before_focus: 1
    end
  end

  @callback after_focus(response :: any()) :: {:ok, any()} | {:error, any()}

  # credo:disable-for-next-line
  def new(attrs) when is_map(attrs) do
    %__MODULE__{
      name: attrs[:name] || "",
      module_name: attrs[:module_name] || "",
      url: attrs[:url] || "",
      method: attrs[:method] || :get,
      params: attrs[:params] || %{},
      headers: attrs[:headers] || [],
      auth: attrs[:auth] || nil,
      description: attrs[:description] || "",
      after_focus: attrs[:after_focus] || fn body -> {:ok, body} end,
      schema: attrs[:schema] || %{}
    }
  end

  def new(attrs) when is_list(attrs) do
    attrs |> Map.new() |> new()
  end

  def focus(lens, opts \\ [])

  def focus(
        %__MODULE__{
          url: url,
          method: method,
          params: params,
          headers: headers,
          after_focus: after_focus
        },
        _opts
      ) do
    [url: url, headers: headers, max_retries: 2]
    |> Keyword.merge(Application.get_env(:lux, :req_options, []))
    |> Req.new()
    |> Req.request([method: method] ++ body_or_params(method, params))
    |> case do
      {:ok, %{status: 200, body: body}} ->
        after_focus.(body)

      {:ok, response} ->
        {:error, response.body}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, inspect(reason)}

      {:error, error} ->
        {:error, inspect(error)}
    end
  end

  def authenticate(%__MODULE__{auth: nil} = lens), do: lens

  def authenticate(%__MODULE__{auth: %{type: :api_key, key: key}} = lens),
    do: update_headers(lens, [{"Authorization", "Bearer #{key}"}])

  def authenticate(
        %__MODULE__{auth: %{type: :basic, username: username, password: password}} = lens
      ),
      do:
        update_headers(lens, [
          {"Authorization", "Basic #{Base.encode64("#{username}:#{password}")}"}
        ])

  def authenticate(%__MODULE__{auth: %{type: :oauth, token: token}} = lens),
    do: update_headers(lens, [{"Authorization", "Bearer #{token}"}])

  def authenticate(%__MODULE__{auth: %{type: :custom, auth_function: func}} = lens),
    do: func.(lens)

  # Helper function to update headers
  defp update_headers(%__MODULE__{headers: headers} = lens, new_headers) do
    %__MODULE__{lens | headers: headers ++ new_headers}
  end

  defp body_or_params(:get, params), do: [params: params]
  defp body_or_params(_method, params), do: [json: params]
end
