# Supervision Tree

* `YourApp.Scheduler` (`Quantum.Scheduler`) - Your primary Interface to interact with. (Like `add_job/1` etc.)
  - `YourApp.Scheduler.Supervisor` (`Quantum.Supervisor`) - The Supervisor that coordinates configuration, the runner and task supervisor.
    * `YourApp.Scheduler.TaskRegistry` (`Quantum.TaskRegistry`) - The `GenServer` that keeps track of running tasks and prevents overlap.
    * `YourApp.Scheduler.JobBroadcaster` (`Quantum.JobBroadcaster`) - The `GenStage` that keeps track of all jobs.
    * `YourApp.Scheduler.ExecutionBroadcaster` (`Quantum.ExecutionBroadcaster`) - The `GenStage` that notifies execution of jobs.
    * `YourApp.Scheduler.ExecutorSupervisor` (`Quantum.ExecutorSupervisor`) - The `ConsumerSupervisor` that spawns an Executor for every execution.
      - `no_name` (`YourApp.Scheduler.Executor`) - The `Task` that calls the `YourApp.Scheduler.Task.Supervisor` with the execution of the cron (per Node).
    * `YourApp.Scheduler.Task.Supervisor` (`Task.Supervisor`) - The `Task.Supervisor` where all cron jobs run in.
      - `Task` - The place where the defined cron job action gets called.

## Error Handling

The OTP Supervision Tree is initiated by the user of the library. Therefore the error handling can be implemented via normal OTP means. See `Supervisor.Spec` for more information.
