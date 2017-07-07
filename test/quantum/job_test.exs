defmodule Quantum.JobTest do
  use ExUnit.Case, async: true

  alias Quantum.Job
  import Crontab.CronExpression

  defmodule Scheduler do
    @moduledoc false

    use Quantum.Scheduler, otp_app: :quantum_test
  end

  test "new/1 returns a new job" do
    assert %Job{} = Scheduler.config |> Job.new
  end

  test "new/1 returns new job with proper configs" do
    configs = Scheduler.config(schedule: "*/7", overlap: false)
    schedule = ~e[*/7]

    assert %Job{schedule: ^schedule, overlap: false} = Job.new(configs)
  end
end
