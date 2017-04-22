# Supervision Tree

* `YourApp.Scheduler` (`Quantum.Scheduler`) - Your primary Interface to interact with. (Like `add_job/1` etc.)
  - `YourApp.Scheduler.Supervisor` (`Quantum.Supervisor`) - The Supervisor that coordinates configuration, the runner and task supervisor.
    * `YourApp.Scheduler.Runner` (`Quantum.Runner`) - The `GenServer` that effectively kicks off cron jobs.
    * `YourApp.Scheduler.Task.Supervisor` (`Task.Supervisor`) - The `Task.Supervisor` where all cron jobs run in.
      - `Task` - The place where the defined cron job action gets called.

## Error Handling

The OTP Supervision Tree is initiated by the user of the library. Therefore the error handling can be implemented via normal OTP means. See `Supervisor.Spec` for more information.
