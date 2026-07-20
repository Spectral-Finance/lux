defmodule Lux.OpenAPITest do
  use ExUnit.Case, async: true

  alias Lux.OpenAPI

  describe "generate/1" do
    test "generates valid OpenAPI spec" do
      assert {:ok, spec} = OpenAPI.generate()

      assert spec.openapi == "3.0.3"
      assert is_map(spec.info)
      assert Map.has_key?(spec.info, :title)
      assert Map.has_key?(spec.info, :version)
      assert is_map(spec.paths)
      assert is_map(spec.components)
    end

    test "generates spec with custom info" do
      assert {:ok, spec} =
               OpenAPI.generate(info: %{title: "Custom API", version: "2.0.0"})

      assert spec.info.title == "Custom API"
      assert spec.info.version == "2.0.0"
    end

    test "generates spec with custom base_path" do
      assert {:ok, spec} = OpenAPI.generate(base_path: "/v2")

      paths = Map.keys(spec.paths)

      if paths != [] do
        assert hd(paths) =~ "/v2"
      end
    end
  end

  describe "validate/1" do
    test "validates correct spec" do
      {:ok, spec} = OpenAPI.generate()
      {:ok, result} = OpenAPI.validate(spec)

      assert result.valid == true
      assert result.errors == []
    end

    test "rejects spec missing openapi field" do
      invalid_spec = %{info: %{title: "Test", version: "1.0"}, paths: %{}}

      assert {:error, errors} = OpenAPI.validate(invalid_spec)
      assert length(errors) > 0
    end

    test "rejects spec with invalid version" do
      invalid_spec = %{
        openapi: "2.0",
        info: %{title: "Test", version: "1.0"},
        paths: %{}
      }

      assert {:error, errors} = OpenAPI.validate(invalid_spec)
      assert Enum.any?(errors, &String.contains?(&1, "version"))
    end
  end

  describe "export/2" do
    test "exports JSON file" do
      filepath = System.tmp_dir!() |> Path.join("test_openapi_#{System.unique_integer([:positive])}.json")

      assert {:ok, path} = OpenAPI.export(filepath)
      assert File.exists?(path)

      content = File.read!(path)
      {:ok, parsed} = Jason.decode(content)
      assert parsed["openapi"] == "3.0.3"

      File.rm(filepath)
    end

    test "exports YAML file" do
      filepath = System.tmp_dir!() |> Path.join("test_openapi_#{System.unique_integer([:positive])}.yaml")

      assert {:ok, path} = OpenAPI.export(filepath)
      assert File.exists?(path)

      content = File.read!(path)
      assert String.contains?(content, "openapi:")

      File.rm(filepath)
    end
  end

  describe "to_json/1" do
    test "renders spec as JSON string" do
      {:ok, spec} = OpenAPI.generate()
      json = OpenAPI.to_json(spec)

      assert is_binary(json)
      {:ok, parsed} = Jason.decode(json)
      assert parsed["openapi"] == "3.0.3"
    end
  end

  describe "to_swagger_html/1" do
    test "generates valid HTML" do
      {:ok, spec} = OpenAPI.generate()
      html = OpenAPI.to_swagger_html(spec)

      assert String.contains?(html, "<!DOCTYPE html>")
      assert String.contains?(html, "swagger-ui")
      assert String.contains?(html, "SwaggerUIBundle")
    end
  end

  describe "build_security_schemes/0" do
    test "returns api key and bearer schemes" do
      schemes = OpenAPI.build_security_schemes()

      assert Map.has_key?(schemes, "ApiKeyAuth")
      assert Map.has_key?(schemes, "BearerAuth")
      assert schemes.ApiKeyAuth.type == "apiKey"
      assert schemes.BearerAuth.scheme == "bearer"
    end
  end

  defmodule SampleLens do
    use Lux.Lens,
      name: "Sample API",
      description: "A sample lens for testing",
      url: "https://api.example.com/v1/data",
      method: :get,
      schema: %{
        type: :object,
        properties: %{
          query: %{type: :string, description: "Search query"},
          limit: %{type: :integer, description: "Max results"}
        },
        required: ["query"]
      }

    def focus(input), do: {:ok, input}
  end

  describe "extract_lens_spec/1" do
    test "extracts spec from a lens module" do
      assert {:ok, spec} = OpenAPI.extract_lens_spec(SampleLens)

      assert spec.method == :get
      assert spec.path =~ "data"
      assert spec.summary == "Sample API"
      assert spec.description =~ "sample lens"
      assert spec.responses != nil
    end
  end

  describe "detect_lenses/0 and detect_prisms/0" do
    test "returns lists of modules" do
      lenses = OpenAPI.detect_lenses()
      prisms = OpenAPI.detect_prisms()

      assert is_list(lenses)
      assert is_list(prisms)
    end
  end
end
