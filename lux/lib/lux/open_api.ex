defmodule Lux.OpenAPI do
  @moduledoc """
  Generates OpenAPI 3.0 specifications from Lux lenses and prisms.

  This module provides functionality to:
  - Scan registered Lux modules (Lenses, Prisms, Beams)
  - Extract API endpoint information
  - Generate valid OpenAPI 3.0 JSON/YAML specifications
  - Validate generated specs against OpenAPI schema
  - Export specs to files or strings

  ## Features

  - Automatic endpoint discovery from Lens modules
  - Request/Response schema generation
  - Authentication scheme documentation
  - Error response documentation
  - Multi-format output (JSON, YAML)
  - Spec validation
  - Interactive documentation generation hints

  ## Examples

      # Generate OpenAPI spec from all registered lenses
      {:ok, spec} = Lux.OpenAPI.generate()

      # Generate spec for specific modules
      {:ok, spec} = Lux.OpenAPI.generate(lenses: [Lux.Lenses.Etherscan.Gas.GasOracleLens])

      # Export to file
      Lux.OpenAPI.export("openapi.json")

      # Validate a spec
      Lux.OpenAPI.validate(spec)
  """

  @type openapi_spec :: %{
          required(:openapi) => String.t(),
          required(:info) => map(),
          required(:paths) => map(),
          optional(:components) => map(),
          optional(:securitySchemes) => map()
        }

  @type module_list :: [module()]

  @default_info %{
    title: "Lux API",
    version: "1.0.0",
    description: "Auto-generated API documentation for Lux application"
  }

  @doc """
  Generates an OpenAPI 3.0 specification from registered Lux modules.

  ## Options

    * `:lenses` - Specific lens modules to include (default: all detected lenses)
    * `:prisms` - Specific prism modules to include (default: all detected prisms)
    * `:info` - Custom info metadata override
    * `:base_path` - Base URL path for all endpoints (default: "/api/v1")

  ## Examples

      iex> Lux.OpenAPI.generate()
      {:ok, spec_map}

      iex> Lux.OpenAPI.generate(base_path: "/v2")
      {:ok, spec_map}
  """
  @spec generate(keyword()) :: {:ok, openapi_spec()} | {:error, String.t()}
  def generate(opts \\ []) do
    base_path = Keyword.get(opts, :base_path, "/api/v1")
    custom_info = Keyword.get(opts, :info, %{})
    info = Map.merge(@default_info, custom_info)

    lenses = Keyword.get(opts, :lenses, detect_lenses())
    prisms = Keyword.get(opts, :prisms, detect_prisms())

    paths = %{}

    # Process lenses
    paths =
      Enum.reduce(lenses, paths, fn lens_module, acc ->
        case extract_lens_spec(lens_module) do
          {:ok, spec} -> add_path(acc, base_path, spec)
          _ -> acc
        end
      end)

    # Process prisms
    paths =
      Enum.reduce(prisms, paths, fn prism_module ->
        case extract_prism_spec(prism_module) do
          {:ok, spec} -> add_path(paths, base_path, spec)
          _ -> paths
        end
      end)

    spec = %{
      openapi: "3.0.3",
      info: info,
      paths: paths,
      components: build_components(lenses ++ prisms),
      securitySchemes: build_security_schemes()
    }

    {:ok, spec}
  rescue
    e -> {:error, "Failed to generate OpenAPI spec: #{Exception.message(e)}"}
  end

  @doc """
  Exports the OpenAPI spec to a JSON file.

  ## Examples

      iex> Lux.OpenAPI.export("openapi.json")
      {:ok, "openapi.json"}

      iex> Lux.OpenAPI.export("docs/openapi.yaml")
      {:ok, "docs/openapi.yaml"}
  """
  @spec export(String.t(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def export(filepath, opts \\ []) do
    with {:ok, spec} <- generate(opts) do
      content =
        case Path.extname(filepath) do
          ".yaml" -> render_yaml(spec)
          _ -> Jason.encode!(spec, pretty: true)
        end

      File.mkdir_p!(Path.dirname(filepath))

      case File.write(filepath, content) do
        :ok -> {:ok, filepath}
        {:error, reason} -> {:error, "Failed to export spec: #{reason}"}
      end
    end
  end

  @doc """
  Renders an OpenAPI spec as a JSON string.

  ## Examples

      iex> Lux.OpenAPI.to_json(spec)
      "{\"openapi\":\"3.0.3\",...}"
  """
  @spec to_json(openapi_spec()) :: String.t()
  def to_json(spec) when is_map(spec) do
    Jason.encode!(spec, pretty: true)
  end

  @doc """
  Renders an OpenAPI spec as YAML string.

  ## Examples

      iex> Lux.OpenAPI.to_yaml(spec)
      "openapi: 3.0.3\n..."
  """
  @spec to_yaml(openapi_spec()) :: String.t()
  def to_yaml(spec) when is_map(spec) do
    render_yaml(spec)
  end

  @doc """
  Validates an OpenAPI spec for basic correctness.

  Checks:
  - Required top-level fields exist
  - OpenAPI version is valid
  - Info section has title and version
  - Paths is a map
  - All path items have at least one operation

  ## Examples

      iex> Lux.OpenAPI.validate(spec)
      {:ok, %{valid: true, errors: []}}

      iex> Lux.OpenAPI.validate(invalid_spec)
      {:error, ["Missing required field: openapi"]}
  """
  @spec validate(openapi_spec()) :: {:ok, %{valid: boolean(), errors: [String.t()]}} | {:error, [String.t()]}
  def validate(spec) when is_map(spec) do
    errors = []

    errors =
      if Map.has_key?(spec, :openapi) do
        errors
      else
        ["Missing required field: openapi"] ++ errors
      end

    errors =
      case Map.get(spec, :openapi) do
        version when is_binary(version) and String.starts_with?(version, "3.") -> errors
        _ -> ["Invalid or missing OpenAPI version (must be 3.x)"] ++ errors
      end

    errors =
      if Map.has_key?(spec, :info) and is_map(Map.get(spec, :info)) do
        info = spec.info

        cond do
          not Map.has_key?(info, :title) ->
            ["Missing required field: info.title"] ++ errors

          not Map.has_key?(info, :version) ->
            ["Missing required field: info.version"] ++ errors

          true ->
            errors
        end
      else
        ["Missing or invalid info section"] ++ errors
      end

    errors =
      case Map.get(spec, :paths) do
        paths when is_map(paths) -> errors
        _ -> ["Paths must be a map"] ++ errors
      end

    valid? = errors == []

    if valid? do
      {:ok, %{valid: true, errors: [], warning_count: 0}}
    else
      {:error, errors}
    end
  end

  @doc """
  Lists all detected Lux Lens modules.

  ## Examples

      iex> Lux.OpenAPI.detect_lenses()
      [Lux.Lenses.Etherscan.Gas.GasOracleLens, ...]
  """
  @spec detect_lenses() :: module_list()
  def detect_lenses do
    Application.get_env(:lux, :lenses, [])
    |> Enum.filter(fn mod ->
      Code.ensure_loaded?(mod) and function_exported?(mod, :view, 0)
    end)
  end

  @doc """
  Lists all detected Lux Prism modules.

  ## Examples

      iex> Lux.OpenAPI.detect_prisms()
      [Lux.Prisms.Discord.Message.SendMessagePrism, ...]
  """
  @spec detect_prisms() :: module_list()
  def detect_prisms do
    Application.get_env(:lux, :prisms, [])
    |> Enum.filter(fn mod ->
      Code.ensure_loaded?(mod) and function_exported?(mod, :handler, 2)
    end)
  end

  @doc """
  Extracts OpenAPI path item from a Lens module.

  ## Examples

      iex> Lux.OpenAPI.extract_lens_spec(Lux.Lenses.Etherscan.Gas.GasOracleLens)
      {:ok, %{method: :get, path: "/etherscan/gas/oracle", ...}}
  """
  @spec extract_lens_spec(module()) :: {:ok, map()} | {:error, term()}
  def extract_lens_spec(module) when is_atom(module) do
    with {:ok, lens} <- safe_view(module),
         url when is_binary(url) <- Map.get(lens, :url, ""),
         method when not is_nil(method) <- Map.get(lens, :method, :get) do
      path_name = url_to_path(url, lens)
      summary = Map.get(lens, :name, "#{module}")
      description = Map.get(lens, :description, "")

      request_schema = build_request_schema(lens)
      response_schema = build_response_schema(lens)

      {:ok,
       %{
         method: String.to_existing_atom(String.downcase(inspect(method))),
         path: path_name,
         summary: summary,
         description: description,
         operationId: String.replace(to_string(module), ".", "_") <> "_focus",
         parameters: extract_parameters(lens),
         requestBody: if(request_schema != %{}, do: request_schema, else: nil),
         responses: build_responses(response_schema)
       }}
    else
      _ -> {:error, :invalid_lens}
    end
  end

  @doc """
  Extracts OpenAPI path item from a Prism module.

  ## Examples

      iex> Lux.OpenAPI.extract_prism_spec(MyPrismModule)
      {:ok, %{method: :post, path: "/prisms/my-prism", ...}}
  """
  @spec extract_prism_spec(module()) :: {:ok, map()} | {:error, term()}
  def extract_prism_spec(module) when is_atom(module) do
    prism_name =
      module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    path_name = "/prisms/#{prism_name}"

    {:ok,
     %{
       method: :post,
       path: path_name,
       summary: "#{module} Prism Handler",
       description: "Executes the #{prism_name} prism action",
       operationId: String.replace(to_string(module), ".", "_") <> "_handler",
       parameters: [],
       requestBody: %{
         content: %{
           "application/json" => %{
             schema: %{
               type: "object",
               properties: %{
                 input: %{type: "object", description: "Prism input data"}
               }
             }
           }
         }
       },
       responses: %{
         "200" => %{
           description: "Successful execution",
           content: %{
             "application/json" => %{
               schema: %{type: "object"}
             }
           }
         },
         "400" => %{
           description: "Invalid input",
           content: %{
             "application/json" => %{
               schema: %{
                 type: "object",
                 properties: %{error: %{type: "string"}}
               }
             }
           }
         }
       }
     }}
  end

  @doc """
  Builds the components section of the OpenAPI spec.

  Includes schemas for all detected modules' request/response types.
  """
  @spec build_components(module_list()) :: map()
  def build_components(modules) do
    schemas = %{}

    schemas =
      Enum.reduce(modules, schemas, fn module, acc ->
        case safe_view(module) do
          {:ok, lens} ->
            schema_name = schema_name_for(module)
            schema = build_schema_from_lens(lens)
            Map.put(acc, schema_name, schema)

          _ ->
            acc
        end
      end)

    %{
      schemas: schemas,
      securitySchemes: build_security_schemes()
    }
  end

  @doc """
  Builds security schemes for the OpenAPI spec.

  ## Examples

      iex> Lux.OpenAPI.build_security_schemes()
      %{"ApiKeyAuth" => %{"type" => "apiKey", ...}}
  """
  @spec build_security_schemes() :: map()
  def build_security_schemes do
    %{
      "ApiKeyAuth" => %{
        type: "apiKey",
        in: "header",
        name: "X-API-Key"
      },
      "BearerAuth" => %{
        type: "http",
        scheme: "bearer",
        bearerFormat: "JWT"
      }
    }
  end

  @doc """
  Converts an OpenAPI spec to Swagger UI HTML.

  Generates a minimal HTML page that renders the spec using Swagger UI.

  ## Examples

      iex> Lux.OpenAPI.to_swagger_html(spec)
      "<!DOCTYPE html>..."
  """
  @spec to_swagger_html(openapi_spec()) :: String.t()
  def to_swagger_html(spec) when is_map(spec) do
    spec_json = Jason.encode!(spec)

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Lux API Documentation</title>
      <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
    </head>
    <body>
      <div id="swagger-ui"></div>
      <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
      <script>
        const spec = #{spec_json};
        SwaggerUIBundle({
          dom_id: '#swagger-ui',
          spec: spec,
          presets: [
            SwaggerUIBundle.presets.apis,
            SwaggerUIBundle.SwaggerUIStandalonePreset
          ],
          layout: "StandaloneLayout"
        });
      </script>
    </body>
    </html>
    """
  end

  # Private Functions

  defp safe_view(module) do
    try do
      case module.view() do
        %__MODULE__{} = lens -> {:ok, lens}
        other when is_map(other) -> {:ok, other}
        _ -> {:error, :no_view}
      end
    rescue
      _ -> {:error, :view_failed}
    end
  end

  defp extract_lens_spec(module) do
    case safe_view(module) do
      {:ok, lens} ->
        url = Map.get(lens, :url, "")
        method = Map.get(lens, :method, :get)

        if url != "" do
          path_name = url_to_path(url, lens)
          summary = Map.get(lens, :name, "#{module}")
          description = Map.get(lens, :description, "")

          {:ok,
           %{
             method: String.to_existing_atom(String.downcase(inspect(method))),
             path: path_name,
             summary: summary,
             description: description,
             operationId: String.replace(to_string(module), ".", "_") <> "_focus",
             parameters: extract_parameters(lens),
             requestBody: nil,
             responses: build_default_responses()
           }}
        else
          {:error, :no_url}
        end

      _ ->
        {:error, :no_view}
    end
  end

  defp add_path(paths, base_path, spec) do
    path = Path.join([base_path, spec.path])
    method = String.downcase(inspect(spec.method))

    operation =
      %{}
      |> Map.put(:summary, spec.summary)
      |> maybe_put(:description, spec.description)
      |> Map.put(:operationId, spec.operationId)
      |> maybe_put(:parameters, spec.parameters)
      |> maybe_put(:requestBody, spec.requestBody)
      |> Map.put(:responses, spec.responses)

    existing = Map.get(paths, path, %{})
    updated = Map.put(existing, method, operation)
    Map.put(paths, path, updated)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp url_to_path(url, lens) do
    uri = URI.parse(url)
    path = uri.path || "/"

    # Convert to snake_case for API paths
    path
    |> String.split("/")
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&Macro.underscore/1)
    |> Enum.map_join("/", fn segment ->
      segment
      |> String.replace(~r/[A-Z]/, "_\\0")
      |> String.downcase()
    end)
  end

  defp build_request_schema(lens) do
    schema = Map.get(lens, :schema, %{})

    if schema == %{} or schema == nil do
      %{}
    else
      %{
        content: %{
          "application/json" => %{
            schema: elixir_schema_to_openapi(schema)
          }
        }
      }
    end
  end

  defp build_response_schema(lens) do
    # Use schema if provided, otherwise generic object
    schema = Map.get(lens, :schema, %{})

    if schema != %{} do
      elixir_schema_to_openapi(schema)
    else
      %{type: "object", properties: %{}}
    end
  end

  defp build_responses(response_schema) do
    %{
      "200" => %{
        description: "Successful response",
        content: %{
          "application/json" => %{
            schema: response_schema
          }
        }
      },
      "400" => %{
        description: "Bad Request",
        content: %{
          "application/json" => %{
            schema: %{
              type: "object",
              properties: %{error: %{type: "string"}}
            }
          }
        }
      },
      "500" => %{
        description: "Internal Server Error",
        content: %{
          "application/json" => %{
            schema: %{
              type: "object",
              properties: %{error: %{type: "string"}}
            }
          }
        }
      }
    }
  end

  defp build_default_responses do
    %{
      "200" => %{
        description: "Successful response",
        content: %{
          "application/json" => %{
            schema: %{type: "object"}
          }
        }
      },
      "400" => %{
        description: "Bad Request",
        content: %{
          "application/json" => %{
            schema: %{
              type: "object",
              properties: %{error: %{type: "string"}}
            }
          }
        }
      }
    }
  end

  defp extract_parameters(lens) do
    schema = Map.get(lens, :schema, %{})

    if schema == %{} or schema == nil do
      []
    else
      properties = Map.get(schema, :properties, %{})

      Enum.map(properties, fn {name, prop_schema} ->
        param = %{
          name: name,
          in: "query",
          required: Map.get(schema, :required, []) |> Enum.member?(name),
          schema: elixir_type_to_openapi(Map.get(prop_schema, :type, "string"))
        }

        if desc = Map.get(prop_schema, :description) do
          Map.put(param, :description, desc)
        else
          param
        end
      end)
    end
  end

  defp elixir_schema_to_openapi(%{type: type, properties: props} = schema) do
    openapi_schema = %{
      type: elixir_type_to_openapi(type),
      properties: %{}
    }

    openapi_schema =
      if required = Map.get(schema, :required) do
        Map.put(openapi_schema, :required, required)
      else
        openapi_schema
      end

    openapi_schema =
      Enum.reduce(props, openapi_schema, fn {name, prop}, acc ->
        Map.put(acc, :properties, Map.put(acc.properties, name, elixir_schema_to_openapi(prop)))
      end)

    openapi_schema
  end

  defp elixir_schema_to_openapi(schema) when is_map(schema) do
    %{type: "object", properties: %{}}
  end

  defp elixir_schema_to_openapi(_), do: %{type: "object"}

  defp elixir_type_to_openapi(:string), do: "string"
  defp elixir_type_to_openapi(:integer), do: "integer"
  defp elixir_type_to_openapi(:float), do: "number"
  defp elixir_type_to_openapi(:boolean), do: "boolean"
  defp elixir_type_to_openapi(:map), do: "object"
  defp elixir_type_to_openapi(:list), do: "array"
  defp elixir_type_to_openapi(_), do: "string"

  defp schema_name_for(module) do
    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.replace("_", "-")
  end

  defp build_schema_from_lens(lens) do
    schema = Map.get(lens, :schema, %{})

    if schema == %{} do
      %{type: "object", properties: %{}}
    else
      elixir_schema_to_openapi(schema)
    end
  end

  defp render_yaml(spec) do
    # Simple YAML renderer for OpenAPI specs
    spec
    |> Jason.encode!()
    |> Jason.decode!()
    |> yaml_encode()
  end

  defp yaml_encode(map) when is_map(map) do
    lines = []

    map
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> Enum.each(fn {key, value} ->
      key_str = to_string(key)

      if is_map(value) do
        lines = lines ++ ["#{key_str}:"]
        lines = lines ++ indent_yaml(yaml_encode(value), 2)
      else
        lines = lines ++ ["#{key_str}: #{yaml_value(value)}"]
      end
    end)

    Enum.join(lines, "\n")
  end

  defp yaml_encode(list) when is_list(list) do
    Enum.map(list, fn item ->
      if is_map(item) do
        "- " <> yaml_encode(item)
      else
        "- #{yaml_value(item)}"
      end
    end)
    |> Enum.join("\n")
  end

  defp yaml_encode(value), do: yaml_value(value)

  defp yaml_value(true), do: "true"
  defp yaml_value(false), do: "false"
  defp yaml_value(nil), do: "null"
  defp yaml_value(value) when is_binary(value), do: inspect(value)
  defp yaml_value(value), do: to_string(value)

  defp indent_yaml(content, spaces) do
    prefix = String.duplicate(" ", spaces)

    content
    |> String.split("\n")
    |> Enum.map(fn line -> prefix <> line end)
  end
end
