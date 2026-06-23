defmodule Lux.Prisms.YouTube.DummyVideoCreatorPrism do
  @moduledoc """
  Simulates video generation by creating a dummy file.
  """
  use Lux.Prism,
    name: "Dummy Video Creator",
    description: "Creates a dummy video file for testing",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{type: :string}
      },
      required: ["title"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        video_path: %{type: :string}
      },
      required: ["video_path"]
    }

  def handler(input, _ctx) do
    title = input[:title] || input["title"] || "untitled"
    # generate a filename
    slug = title |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "_") |> String.trim("_")
    path = "tmp/#{slug}_#{System.unique_integer([:positive])}.mp4"
    File.mkdir_p!("tmp")
    File.write!(path, "fake video data")
    {:ok, %{video_path: path}}
  end
end
