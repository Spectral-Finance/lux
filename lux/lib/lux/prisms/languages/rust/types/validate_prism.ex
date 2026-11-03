defmodule Lux.Prisms.Languages.Rust.Types.ValidatePrism do
  @moduledoc """
  A prism that validates data integrity across serialization/deserialization roundtrips.
  """

  use Lux.Prism,
    name: "Rust Type Validator",
    description: "Validates roundtrip data equality across Elixir and Rust type conversions",
    input_schema: %{
      type: :object,
      properties: %{
        original: %{
          type: [:object, :array, :string, :number, :boolean, :null]
        },
        roundtripped: %{
          type: [:object, :array, :string, :number, :boolean, :null]
        }
      },
      required: ["original", "roundtripped"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        is_match: %{type: :boolean},
        status: %{type: :string}
      },
      required: ["is_match", "status"]
    }

  @impl true
  def handler(inputs, _context) do
    orig = Map.get(inputs, "original") || Map.get(inputs, :original)
    round = Map.get(inputs, "roundtripped") || Map.get(inputs, :roundtripped)

    # Normalize both for comparison (string keys)
    norm_orig = normalize(orig)
    norm_round = normalize(round)

    is_match = norm_orig == norm_round

    {:ok,
     %{
       is_match: is_match,
       status: if(is_match, do: "valid", else: "mismatch")
     }}
  end

  defp normalize(%{__struct__: _} = s), do: s |> Map.from_struct() |> normalize()
  defp normalize(m) when is_map(m) do
    Map.new(m, fn {k, v} -> {to_string(k), normalize(v)} end)
  end
  defp normalize(l) when is_list(l), do: Enum.map(l, &normalize/1)
  defp normalize(other), do: other
end
