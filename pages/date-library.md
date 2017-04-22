# Date Library

This library can be used independent from `timex`.

Any date library can be used by implementing the `Quantum.DateLibrary` behavior.

**The library does not respect semver for this behaviour. Breaking Changes will
happen even in patch releases.**

To use another date library, change the implementation like this:

```elixir
config :quantum,
  date_library: Quantum.DateLibrary.Timex
```

## Supported Date Libraries

* [`timex`](https://hex.pm/packages/timex) - `Quantum.DateLibrary.Timex`
* [`calendar`](https://hex.pm/packages/calendar) - `Quantum.DateLibrary.Calendar`
