# Run Strategies

Tasks can be executed via different run strategies.

## Configuration

### Mix

```elixir
config :my_app, MyApp.Scheduler,
  jobs: [
    [schedule: "* * * * *", run_strategy: {StrategyName, options}],
  ]
```

The run strategy can be configured by providing a tuple of the strategy module name and it's options. If you choose `Local Node` strategy, the config should be:

```elixir
config :my_app, MyApp.Scheduler,
  jobs: [
    [schedule: "* * * * *", run_strategy: Quantum.RunStrategy.Local],
  ]
```

### Runtime

Provide a value that implements the `Quantum.RunStrategy.NodeList` protocol. The value will not be normalized.

## Provided Strategies

### All Nodes

`Quantum.RunStrategy.All`

If you want to run a task on all nodes of either a list or in the whole cluster, use this strategy.

### Random Node

`Quantum.RunStrategy.Random`

If you want to run a task on any node of either a list or in the whole cluster, use this strategy.

In case you have variable applications in cluster nodes, and you want include only specific app nodes, add to config.exs
```
config :quantum, Quantum.RunStrategy.Random,
  node_application: :your_otp_app

Only nodes that contains `:your_otp_app` will be selected to nodes list to execute
```

### Local Node

`Quantum.RunStrategy.Local`

If you want to run a task on local node, use this strategy.

## Custom Run Strategy

Custom run strategies, can be implemented by implementing the `Quantum.RunStrategy` behaviour and the `Quantum.RunStrategy.NodeList` protocol.
