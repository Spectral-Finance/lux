defp deps do
  [
    {:httpoison, "~> 1.8"},
    {:poison, "~> 5.0"},
    {:youtube_community_manager, "~> 0.1.0"}
  ]
end

## Agent Setup and Usage

To set up the YouTube Community Manager agent, follow these steps:

1. Add the required dependencies to your `mix.exs` file:
   defp deps do
     [
       {:httpoison, "~> 1.8"},
       {:poison, "~> 5.0"},
       {:youtube_community_manager, "~> 0.1.0"}
     ]
   end

2. Start the agent by running:
   iex -S mix
   YouTubeCommunityManager.start_link()

3. Use the agent to manage your YouTube community:
   YouTubeCommunityManager.add_video("video_id", "title")
   YouTubeCommunityManager.remove_video("video_id")
   YouTubeCommunityManager.update_video("video_id", "new_title")

For more detailed information, refer to the [YouTube Community Manager documentation](https://github.com/example/youtube_community_manager).