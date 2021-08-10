# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## Unreleased

Diff for [unreleased]

## 3.4.0 - 2021-08-10

### Added
- `telemetry` `v1.0.0` support (#483)
- Logger Metadata (#462 & #464)
- Support setting job `state` in config (#463)

### Fixed
- Invalid Timezone fix in `ExecutionBroadcaster` (#468)

Diff for [3.4.0]

## 3.3.0 - 2020-09-25

### Added
- Support manual job triggering (#459)

Diff for [3.3.0]

## 3.2.0 - 2020-09-14

### Added
- Telemetry Support (#415)

### Fixed
- Properly override jobs with duplicate name (#392)
- Simplify `TaskRegistry` and make tests deterministic

Diff for [3.2.0]

## 3.1.0 - 2020-08-18

### Added
- Additional Supervisor Configuration for Clustering (#450)

Diff for [3.1.0]

## 3.0.2 - 2020-08-18

### Fixed
- Fix Warnings with Clock Skew (#449)

Diff for [3.0.2]

## 3.0.1 - 2020-06-16

### Fixed
- `ClockEvent` order corrected

Diff for [3.0.1]

## 3.0.0 - 2020-06-11

### Fixed
- Fix `@reboot` Cron Expression (#437)

Diff for [3.0.0]

## 3.0.0-rc.3 - 2020-02-28

### Fixed
- Update Docs

Diff for [3.0.0-rc.3]

## 3.0.0-rc.2 - 2020-02-28

### Changed
- The `Quantum.Storage` behaviour contains a new  mandatory `child_spec/1` callback.

Diff for [3.0.0-rc.2]

## 3.0.0-rc.1 - 2020-02-26

### Changed

- A lot of function that were not for public use have been undocumented. Those are now considered internal and may break at any point in time.
- `Quantum.Scheduler` has been renamed to `Quantum`
- `Quantum.Storage.Adapter` has been renamed to `Quantum.Storage`
- The `global` mode has been removed. It will be reimplemented if a stable replacement is found.

Diff for [3.0.0-rc.1]

## 2.4.0 - 2020-02-25

### Added
- Native Date Library (via #405)
- Adding of inactive Jobs (via #409)

### Fixed
- GenStage 1.0 compatibility (via #424)
- Doc Fixes (#394, #396, #400, #401)

Diff for [2.4.0]

## 2.3.4 - 2019-01-06

### Fixed
- Faster Startup duration for non-global (Fixes #376)

Diff for [2.3.4]

## 2.3.3 - 2018-09-06

### Fixed
- Fix & Test Swarm Handoff & Conflict Resolution
- Fix Compilation Error
- Fix Executor Stat Options for GenStage ~> 0.12.0

Diff for [2.3.3]

## 2.3.2 - 2018-08-21

### Fixed
- Global Clustering Worker Start

Diff for [2.3.2]

## 2.3.1 - 2018-08-13

### Fixed
- Fixed Regression in Run Strategy Random

Diff for [2.3.1]

## 2.3.0 - 2018-08-10

### Added
- Experimental Storage API

### Fixed
- Use Swarm for clustering to prevent broken cluster state
- Better search for available nodes for run strategies

Diff for [2.3.0]

## 2.2.7 - 2018-03-22

### Changed
- Moved the Repository into Organization & Correct all the URL's

### Fixed
- Fixed Dialyzer Warnings

Diff for [2.2.7]

## 2.2.6 - 2018-03-21

### Fixed
- Fixed problem with Daylight Saving Time for jobs with timezone other than UTC.

Diff for [2.2.6]

## 2.2.5 - 2018-02-26

### Fixed
- Omit `gen_stage` warning on `~> 0.13`

Diff for [2.2.5]

## 2.2.4 - 2018-02-23

### Fixed
- Relax `timex` dependency

Diff for [2.2.4]

## 2.2.3 - 2018-02-13

### Fixed
- Fixed compatibility with `gen_stage ~> 0.12`

Diff for [2.2.3]

## 2.2.2 - 2018-02-08

### Added
- Better Debugging Capabilities

### Fixed
- Relaxed version requirements for `gen_stage`

Diff for [2.2.2]

## 2.2.1 - 2018-01-03

### Fixed
- sometimes the task supervisor was not running in a cluster

Diff for [2.2.1]

## 2.2.0 - 2017-11-07

Diff for [2.2.0]

### Added
- Local run strategy

## 2.1.3 - 2017-11-07

Diff for [2.1.3]

### Fixed
- Runtime Added Jobs are executed right away instead of waiting for the next job execution.
- Fix Typo in Doc

## 2.1.2 - 2017-11-04

Diff for [2.1.2]

### Added
- Distillery is not mentioned in list of package managers

### Changed
- Source is not formatted properly

### Fixed
- Removed unused Alias from `Quantum.Job`
- Hot upgrade is not possible due to missing supervisor

## 2.1.1 - 2017-10-02

Diff for [2.1.1]

### Fixed
- Resolved some Dialyzer Warnings

## 2.1.0 - 2017-09-10

Diff for [2.1.0]

### Fixed
- Resolved some Dialyzer Warnings

## 2.1.0-beta.1 - 2017-08-20

Diff for [2.1.0-beta.1]

The internal handling has been refactored onto `gen_stage`.
There were a few Breaking Changes which should not influence a user of the library.

### Changed
- Replaced `call` with `cast`
  * `Scheduler.add_job`
  * `Scheduler.deactivate_job`
  * `Scheduler.activate_job`
  * `Scheduler.delete_job`
  * `Scheduler.delete_all_jobs`

### Removed
- The overlap handling is removed from the Job struct.
  * removed `Job.pids`
  * removed `Job.executable?`

## 2.0.4 - 2017-09-01

Diff for [2.0.4]

### Fixed
- Fix Race Condition with reboot in Runner state

## 2.0.3 - 2017-08-29

Diff for [2.0.3]

### Fixed
- `@reboot` cron expressions

## 2.0.2 - 2017-08-23

Diff for [2.0.2]

### Fixed
- Updated Docs.

## 2.0.1 - 2017-08-23

Diff for [2.0.1]

- Timezone in job configuration is now normalized into a job.

## 2.0.0 - 2017-07-20

Diff for [2.0.0]

The whole library has been refactored. See the [Migration Guide](https://hexdocs.pm/quantum/migrate-v2.html).

## 2.0.0-beta.2 - 2017-07-13

Diff for [2.0.0-beta.2]

The whole library has been refactored. See the [Migration Guide](https://hexdocs.pm/quantum/migrate-v2.html).

## 2.0.0-beta.1 - 2017-06-07

Diff for [2.0.0-beta.1]

The whole library has been refactored. See the [Migration Guide](https://hexdocs.pm/quantum/migrate-v2.html).

## 1.9.2 - 2017-05-19

Diff for [1.9.2]

## 1.9.1 - 2017-03-17

Diff for [1.9.1]

## 1.9.0 - 2017-02-07

Diff for [1.9.0]

### Removed
- Three modules were removed and replaced by [crontab](https://hex.pm/packages/crontab).
  * `Quantum.Matcher`
  * `Quantum.Parser`
  * `Quantum.Translator`

### Fixed
- The whole cron expression syntax is now supported.
- Crons can now be configured for Umbrella applications. See the `README` for the new syntax.

### Changed
- Cron Expressions can now be provided via the `%Crontab.CronExpression{}` struct or via the `~e[CRON EXPRESSION]` sigil.
- Cron Expressions can now be extended. This way second granularity of the expressions can be provided.

### Deprecated
- The configuration property `cron` is deprecated. Use the app configuration instead.

## 1.8.1 - 2016-11-20

Diff for [1.8.1]

### Changed
- Clarity on the table to not use full name of day ([Coburn Berry](https://github.com/crododile))
- Travis testing against erlang 19.1 and elixir 1.3.3 ([Julius Beckmann](https://github.com/h4cc))
- Don't allow "local" timezone. Replace Timex w. Calendar ([Lau Taarnskov](https://github.com/lau))

### Fixed
- Global cannot be used directly ([Po Chen](https://github.com/princemaple))
- Support for timezones other than utc or local not in readme ([Coburn Berry](https://github.com/crododile))
- Timezone as string not working in config ([Daniel Roux](https://github.com/xrx))

### Removed
- Timex references in readme ([Coburn Berry](https://github.com/crododile))
- License badge in README

## 1.8.0 - 2016-09-19

Diff for [1.8.0]

### Changed
- Requires Elixir >= 1.3
- Updated C4 contribution process to RFC42
- Updated timex dependency to 3.0 ([Svilen Gospodinov](https://github.com/svileng))

### Fixed
- Same task could be generated multiple times in a cluster ([Po Chen](https://github.com/princemaple))
- Elixir 1.3.0 introduced unsafe var warnings ([Jamie J Quinn](https://github.com/JamieJQuinn))
- Typo in README ([Uģis Ozols](https://github.com/ugisozols))
- Code coverage below 100% ([Lucas Charles](https://github.com/theoretick))

### Removed
- Unused alias ([Philip Giuliani](https://github.com/philipgiuliani))

## 1.7.1 - 2016-03-24

Diff for [1.7.1]

### Added
- Optional per-job timezone support

### Fixed
- Nodes defaulting in `%Quantum.Job` struct
- `job.nodes` defaulting in the normalizer
- Test suite after changing defaulting of nodes property for the `%Quantum.Jobs{}` struct

## 1.7.0 - 2016-03-09

Diff for [1.7.0]

### Added
- ToC to README
- Documentation for `overlap` option
- Elixir 1.2 to Travis-CI config
- Prevent duplicate job-names at runtime ([Kai Faber](https://github.com/kaiatgithub))

### Changed
- ToC markdown
- Default values are now configurable
- Updated all dependencies
- Required Elixir version is now `>= 1.2`

### Fixed
- Overlap option was not set to jobs
- Incorrect example in README
- Timezone is not configurable at runtime
- Credo warnings
- GenServer restarts when one of the jobs crashes (#82)

## 1.6.1 - 2015-12-09

Diff for [1.6.1]

### Fixed
- `@reboot` entries are throwing errors
- Credo warnings and software design suggestions
- Elixir 1.2 warnings

### Changed
- Dependency 'credo' updated
- Refactored range variables
- `.gitignore` updated

## 1.6.0 - 2015-11-25

Diff for [1.6.0]

### Added
- PID of last executed task to job struct
- Credo code linter (only for dev and test)
- Total downloads badge to README
- Elixir 1.1.0 and Erlang 18.1 to Travis-CI config

### Fixed
- Max hour is 23, not 24
- Long-running jobs could overlap
- Typo in README ([Lucas Charles](https://github.com/theoretick))
- Incorrect function and response types in readme ([Bart van Zon](https://github.com/bartj3))
- Unnamed job tuples cannot take args ([Lucas Charles](https://github.com/theoretick))
- Job names can only be atoms and can't be GC ([Luis Hurtado](https://github.com/luishurtado))

## 1.5.0 - 2015-09-24

Diff for [1.5.0]

### Added
- Ability to run jobs on exact node ([Rodion Vshevtsov](https://github.com/alPacino))
- Documentation of named jobs
- OTP 17.5 and 18.0 to Travis tests

### Changed
- `ex_doc` dependency version

### Fixed
- Typos in README

## 1.4.0 - 2015-09-02

Diff for [1.4.0]

### Added
- Named jobs and the ability to (de)activate them ([Rodion Vshevtsov](https://github.com/alPacino))
- Doc annotations for functions
- Inch-CI integration

### Changed
- Updated `ex_doc` dependency

## 1.3.2 - 2015-08-22

Diff for [1.3.2]

### Added
- Timezone option to README.

### Fixed
- Using `@reboot` lead to crash.

## 1.3.1 - 2015-07-27

Diff for [1.3.1]

### Added
- Added contributors to changelog and project description
- Option to use local timezone instead of UTC.

### Changed
- Tables in README use markdown format

## 1.3.0 - 2015-07-15

Diff for [1.3.0]


### Added
- Allow cron-like job formatting (`"* * * * * MyApp.MyModule.my_method"`) ([Rodion Vshevtsov](https://github.com/alPacino))
- Allow defining functions as tuple (`{"Module", :method}`) in config ([Rodion Vshevtsov](https://github.com/alPacino))
- Note about UTC ([Lenz Gschwendtner](https://github.com/norbu09))

## 1.2.4 - 2015-06-22

Diff for [1.2.4]

### Changed
- Renamed parse/5 functions to do_parse/5 and made them private
- Always use `{expression, fun}` for jobs
- Moved duplicate code to new private function `only_multiplier_of/2`
- Moved code to normalize jobs to separate module
- Correctly use passed state in Quantum.init/1 function
- Moved reboot logic to executor.

### Removed
- Unnecessary guard clause
- Unused parse/3 functions
- Unused call to String.split on patterns starting with "*/"

## 1.2.3 - 2015-06-15

Diff for [1.2.3]

### Added
- Support for `@reboot`

### Fixed
- Does not convert jobs defined in config

## 1.2.2 - 2015-06-15

Diff for [1.2.2]

### Added
- Support for `@annually` and `@midnight`

### Changed
- Function order in Quantum.Matcher
- Renamed private translate function to do_translate
- Do not convert and translate cron expressions on every tick

### Fixed
- Adding a job using Quantum.add_job/2 does not convert to lowercase
- Adding a job using Quantum.add_job/2 does not translate day/month names

## 1.2.1 - 2015-06-13

Diff for [1.2.1]

### Added
- Test for handle_info(:tick_state)
- Dependencies to generate hexdocs
- Badge for hexdocs
- Link to docs in hex package info
- Type specs and doc annotations

### Changed
- Quantum.Application does not call Quantum.start_link/1 anymore
- Moved match logic to separate module Quantum.Matcher
- Moved parsing logic to separate module Quantum.Parser
- Moved execution logic to separate module Quantum.Executor
- Moved translation logic to separate module Quantum.Translator

### Fixed
- Typos in changelog

### Removed
- Quantum.start_link/1

## 1.2.0 - 2015-06-11

Diff for [1.2.0]

### Changed
- Date is updated in state only if it changed
- Wake up every minute instead of every second

### Fixed
- Intervals on ranges are not correctly parsed
- Hour constraints are not correct ([Lenz Gschwendtner](https://github.com/norbu09))
- There is no changelog
- Code coverage is low
- Explicit variables are not needed
- Pattern matching can be simplified

## 1.1.0 - 2015-05-28

Diff for [1.1.0]

### Added
- Add ability to schedule jobs at runtime and ability to view jobs ([Dan Swain](https://github.com/dantswain))

### Changed
- Relax Elixir version

## 1.0.4 - 2015-05-26

Diff for [1.0.4]

### Fixed
- Written month and weekday names are not parsed

## 1.0.3 - 2015-05-01

Diff for [1.0.3]

### Fixed
- Do not fire on first tick

## 1.0.2 - 2015-04-29

Diff for [1.0.2]

### Fixed
- Special expressions are not correctly in all cases

### Removed
- Functions to add and reset jobs

## 1.0.1 - 2015-04-27

Diff for [1.0.1]

### Added
- Configure cronjobs in config
- Add application

### Fixed
- Parsing of cron expression fails

## 1.0.0 - 2015-04-27

Diff for [1.0.0]

### Added
- Initial commit

[unreleased]: https://github.com/quantum-elixir/quantum-core/compare/v3.4.0...HEAD
[3.4.0]: https://github.com/quantum-elixir/quantum-core/compare/v3.3.0...v3.4.0
[3.3.0]: https://github.com/quantum-elixir/quantum-core/compare/v3.2.0...v3.3.0
[3.2.0]: https://github.com/quantum-elixir/quantum-core/compare/v3.1.0...v3.2.0
[3.1.0]: https://github.com/quantum-elixir/quantum-core/compare/v3.0.2...v3.1.0
[3.0.2]: https://github.com/quantum-elixir/quantum-core/compare/v3.0.1...v3.0.2
[3.0.1]: https://github.com/quantum-elixir/quantum-core/compare/v3.0.0...v3.0.1
[3.0.0]: https://github.com/quantum-elixir/quantum-core/compare/v3.0.0-rc.3...v3.0.0
[3.0.0-rc.3]: https://github.com/quantum-elixir/quantum-core/compare/v3.0.0-rc.2...v3.0.0-rc.3
[3.0.0-rc.2]: https://github.com/quantum-elixir/quantum-core/compare/v3.0.0-rc.1...v3.0.0-rc.2
[3.0.0-rc.1]: https://github.com/quantum-elixir/quantum-core/compare/v2.4.0...v3.0.0-rc.1
[2.4.0]: https://github.com/quantum-elixir/quantum-core/compare/v2.3.4...v2.4.0
[2.3.4]: https://github.com/quantum-elixir/quantum-core/compare/v2.3.3...v2.3.4
[2.3.3]: https://github.com/quantum-elixir/quantum-core/compare/v2.3.2...v2.3.3
[2.3.2]: https://github.com/quantum-elixir/quantum-core/compare/v2.3.1...v2.3.2
[2.3.1]: https://github.com/quantum-elixir/quantum-core/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/quantum-elixir/quantum-core/compare/v2.2.7...v2.3.0
[2.2.7]: https://github.com/quantum-elixir/quantum-core/compare/v2.2.6...v2.2.7
[2.2.6]: https://github.com/quantum-elixir/quantum-core/compare/v2.2.5...v2.2.6
[2.2.5]: https://github.com/quantum-elixir/quantum-core/compare/v2.2.4...v2.2.5
[2.2.4]: https://github.com/quantum-elixir/quantum-core/compare/v2.2.3...v2.2.4
[2.2.3]: https://github.com/quantum-elixir/quantum-core/compare/v2.2.2...v2.2.3
[2.2.2]: https://github.com/quantum-elixir/quantum-core/compare/v2.2.1...v2.2.2
[2.2.1]: https://github.com/quantum-elixir/quantum-core/compare/v2.2.0...v2.2.1
[2.2.0]: https://github.com/quantum-elixir/quantum-core/compare/v2.1.3...v2.2.0
[2.1.3]: https://github.com/quantum-elixir/quantum-core/compare/v2.1.2...v2.1.3
[2.1.2]: https://github.com/quantum-elixir/quantum-core/compare/v2.1.1...v2.1.2
[2.1.1]: https://github.com/quantum-elixir/quantum-core/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/quantum-elixir/quantum-core/compare/v2.1.0-beta.1...v2.1.0
[2.1.0-beta.1]: https://github.com/quantum-elixir/quantum-core/compare/v2.0.4...v2.1.0-beta.1
[2.0.4]: https://github.com/quantum-elixir/quantum-core/compare/v2.0.3...v2.0.4
[2.0.3]: https://github.com/quantum-elixir/quantum-core/compare/v2.0.2...v2.0.3
[2.0.2]: https://github.com/quantum-elixir/quantum-core/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/quantum-elixir/quantum-core/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/quantum-elixir/quantum-core/compare/v2.0.0-beta.2...v2.0.0
[2.0.0-beta.2]: https://github.com/quantum-elixir/quantum-core/compare/v2.0.0-beta.1...v2.0.0-beta.2
[2.0.0-beta.1]: https://github.com/quantum-elixir/quantum-core/compare/v1.9.2...v2.0.0-beta.1
[1.9.2]: https://github.com/quantum-elixir/quantum-core/compare/v1.9.1...v1.9.2
[1.9.1]: https://github.com/quantum-elixir/quantum-core/compare/v1.9.0...v1.9.1
[1.9.0]: https://github.com/quantum-elixir/quantum-core/compare/v1.8.1...v1.9.0
[1.8.1]: https://github.com/quantum-elixir/quantum-core/compare/v1.8.0...v1.8.1
[1.8.0]: https://github.com/quantum-elixir/quantum-core/compare/v1.7.1...v1.8.0
[1.7.1]: https://github.com/quantum-elixir/quantum-core/compare/v1.7.0...v1.7.1
[1.7.0]: https://github.com/quantum-elixir/quantum-core/compare/v1.6.1...v1.7.0
[1.6.1]: https://github.com/quantum-elixir/quantum-core/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/quantum-elixir/quantum-core/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/quantum-elixir/quantum-core/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/quantum-elixir/quantum-core/compare/v1.3.2...v1.4.0
[1.3.2]: https://github.com/quantum-elixir/quantum-core/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/quantum-elixir/quantum-core/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/quantum-elixir/quantum-core/compare/v1.2.4...v1.3.0
[1.2.4]: https://github.com/quantum-elixir/quantum-core/compare/v1.2.3...v1.2.4
[1.2.3]: https://github.com/quantum-elixir/quantum-core/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/quantum-elixir/quantum-core/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/quantum-elixir/quantum-core/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/quantum-elixir/quantum-core/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/quantum-elixir/quantum-core/compare/v1.0.4...v1.1.0
[1.0.4]: https://github.com/quantum-elixir/quantum-core/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/quantum-elixir/quantum-core/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/quantum-elixir/quantum-core/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/quantum-elixir/quantum-core/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/quantum-elixir/quantum-core/commit/9a58b5f5c02a2de6cde4c579c9f879f1fb49b305
