defmodule Lux.Prisms.Languages.Rust.ErrorPrism do
  @moduledoc """
  A prism that exercises error propagation and panic isolation in the Rust integration.
  """

  use Lux.Prism,
    name: "Rust Error Handler",
    description: "Safely handles Rust errors, argument violations, and isolated panics",
    input_schema: %{
      type: :object,
      properties: %{
        trigger: %{
          type: :string,
          enum: ["invalid_arg", "not_found", "valid"],
          default: "valid"
        }
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        caught_error: %{type: :boolean},
        error_type: %{type: [:string, :null]},
        message: %{type: [:string, :null]}
      },
      required: ["caught_error"]
    }

  alias Lux.Rust

  @impl true
  def handler(inputs, _context) do
    trigger = Map.get(inputs, "trigger") || Map.get(inputs, :trigger, "valid")

    case trigger do
      "valid" ->
        {:ok, %{caught_error: false, error_type: nil, message: "No error"}}

      "not_found" ->
        case Rust.call("nonexistent.function", %{}) do
          {:error, %Rust.Error{} = err} ->
            {:ok,
             %{
               caught_error: true,
               error_type: Atom.to_string(err.type),
               message: err.message
             }}

          {:ok, _} ->
            {:error, "Expected function not found error"}
        end

      "invalid_arg" ->
        case Rust.call("math.fibonacci", %{"n" => -5}) do
          {:error, %Rust.Error{} = err} ->
            {:ok,
             %{
               caught_error: true,
               error_type: Atom.to_string(err.type),
               message: err.message
             }}

          {:ok, _} ->
            {:error, "Expected invalid argument error"}
        end
    end
  end
end
