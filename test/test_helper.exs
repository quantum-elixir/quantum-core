Application.ensure_all_started(:timex)
Application.ensure_all_started(:quantum)

ExUnit.start(capture_log: true)
