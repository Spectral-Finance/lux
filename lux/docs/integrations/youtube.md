# YouTube Integration Documentation

This document provides instructions on how to integrate with the YouTube Data API v3 using the Lux library.

## Installation

To use the YouTube integration, you need to add the following dependency to your `mix.exs` file:

defp deps do
  [
    {:lux, "~> 0.1"}
  ]
end

Then run `mix deps.get` to fetch and install the dependency.

## Configuration

Before using the YouTube integration, you need to configure your API key in your application's configuration file (`config/config.exs`):

config :lux, youtube_api_key: "your_youtube_api_key_here"

Replace `"your_youtube_api_key_here"` with your actual YouTube Data API v3 key.

## Usage

To search for videos on YouTube, you can use the `Lux.Integrations.Youtube.Client.search/1` function. Here is an example:

iex> Lux.Integrations.Youtube.Client.search("Elixir")
{:ok,
 %{
   "items" => [
     %{
       "id" => %{"kind" => "youtube#video", "videoId" => "example_video_id"},
       "snippet" => %{
         "title" => "Example Video Title",
         "description" => "Example video description",
         "thumbnails" => %{
           "default" => %{"url" => "https://example.com/default_thumbnail.jpg"}
         }
       }
     }
   ]
 }}

The `search/1` function takes a query string as an argument and returns a tuple. The first element of the tuple is either `:ok` or `:error`, depending on whether the request was successful or not. If the request was successful, the second element is a map containing the search results.

## Error Handling

If there is an error fetching YouTube search results, the function will log an error message and return `{:error, reason}`. The `reason` can be any of the errors returned by the HTTPoison library.

For more information on the YouTube Data API v3, please refer to the [official documentation](https://developers.google.com/youtube/v3/docs).