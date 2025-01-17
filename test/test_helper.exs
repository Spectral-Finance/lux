Logger.configure(level: :debug)

Application.put_env(:lux, :req_options, plug: {Req.Test, Lux.Lens})
Application.put_env(:lux, Lux.LLM.OpenAI, plug: {Req.Test, Lux.LLM.OpenAI})

ExUnit.start()
