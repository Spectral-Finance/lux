def handle_call({:fetch_comments, video_id}, _from, state) do
    comments = Lux.Integrations.Youtube.Client.fetch_comments(video_id)
    {:reply, comments, state}
  end
