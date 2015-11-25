# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

## [1.6.0] - 2015-11-25
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

## [1.5.0] - 2015-09-24
### Added
- Ability to run jobs on exact node ([Rodion Vshevtsov](https://github.com/alPacino))
- Documentation of named jobs
- OTP 17.5 and 18.0 to Travis tests

### Changed
- `ex_doc` dependency version

### Fixed
- Typos in README

## [1.4.0] - 2015-09-02
### Added
- Named jobs and the ability to (de)activate them ([Rodion Vshevtsov](https://github.com/alPacino))
- Doc annotations for functions
- Inch-CI integration

### Changed
- Updated `ex_doc` dependency

## [1.3.2] - 2015-08-22
### Added
- Timezone option to README.

### Fixed
- Using `@reboot` lead to crash.

## [1.3.1] - 2015-07-27
### Added
- Added contributors to changelog and project description
- Option to use local timezone instead of UTC.

### Changed
- Tables in README use markdown format

## [1.3.0] - 2015-07-15

### Added
- Allow cron-like job formatting (`"* * * * * MyApp.MyModule.my_method"`) ([Rodion Vshevtsov](https://github.com/alPacino))
- Allow defining functions as tuple (`{"Module", :method}`) in config ([Rodion Vshevtsov](https://github.com/alPacino))
- Note about UTC ([Lenz Gschwendtner](https://github.com/norbu09))

## [1.2.4] - 2015-06-22
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

## [1.2.3] - 2015-06-15
### Added
- Support for `@reboot`

### Fixed
- Does not convert jobs defined in config

## [1.2.2] - 2015-06-15
### Added
- Support for `@annually` and `@midnight`

### Changed
- Function order in Quantum.Matcher
- Renamed private translate function to do_translate
- Do not convert and translate cron expressions on every tick

### Fixed
- Adding a job using Quantum.add_job/2 does not convert to lowercase
- Adding a job using Quantum.add_job/2 does not translate day/month names

## [1.2.1] - 2015-06-13
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

## [1.2.0] - 2015-06-11
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

## [1.1.0] - 2015-05-28
### Added
- Add ability to schedule jobs at runtime and ability to view jobs ([Dan Swain](https://github.com/dantswain))

### Changed
- Relax Elixir version

## [1.0.4] - 2015-05-26
### Fixed
- Written month and weekday names are not parsed

## [1.0.3] - 2015-05-01
### Fixed
- Do not fire on first tick

## [1.0.2] - 2015-04-29
### Fixed
- Special expressions are not correctly in all cases

### Removed
- Functions to add and reset jobs

## [1.0.1] - 2015-04-27
### Added
- Configure cronjobs in config
- Add application

### Fixed
- Parsing of cron expression fails

## [1.0.0] - 2015-04-27
### Added
- Initial commit


[unreleased]: https://github.com/c-rack/quantum-elixir/compare/v1.6.0...HEAD
[1.6.0]: https://github.com/c-rack/quantum-elixir/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/c-rack/quantum-elixir/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/c-rack/quantum-elixir/compare/v1.3.2...v1.4.0
[1.3.2]: https://github.com/c-rack/quantum-elixir/compare/v1.3.1...v1.3.2
[1.3.1]: https://github.com/c-rack/quantum-elixir/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/c-rack/quantum-elixir/compare/v1.2.4...v1.3.0
[1.2.4]: https://github.com/c-rack/quantum-elixir/compare/v1.2.3...v1.2.4
[1.2.3]: https://github.com/c-rack/quantum-elixir/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/c-rack/quantum-elixir/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/c-rack/quantum-elixir/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/c-rack/quantum-elixir/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/c-rack/quantum-elixir/compare/v1.0.4...v1.1.0
[1.0.4]: https://github.com/c-rack/quantum-elixir/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/c-rack/quantum-elixir/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/c-rack/quantum-elixir/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/c-rack/quantum-elixir/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/c-rack/quantum-elixir/commit/9a58b5f5c02a2de6cde4c579c9f879f1fb49b305
