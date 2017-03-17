# Crontab format

## Basics

| Field        | Allowed values                              |
| ------------ | ------------------------------------------- |
| minute       | 0-59                                        |
| hour         | 0-23                                        |
| day of month | 1-31                                        |
| month        | 1-12 (or names)                             |
| day of week  | 0-6 (0 is Sunday, or use abbreviated names) |

Names can also be used for the `month` and `day of week` fields.
Use the first three letters of the particular day or month (case does not matter).

## Special expressions

Instead of the first five fields, one of these special strings may be used:

| String      | Description                                           |
| ----------- | ----------------------------------------------------- |
| `@annually` | Run once a year, same as `"0 0 1 1 *"` or `@yearly`   |
| `@daily`    | Run once a day, same as `"0 0 * * *"` or `@midnight`  |
| `@hourly`   | Run once an hour, same as `"0 * * * *"`               |
| `@midnight` | Run once a day, same as `"0 0 * * *"` or `@daily`     |
| `@monthly`  | Run once a month, same as `"0 0 1 * *"`               |
| `@reboot`   | Run once, at startup                                  |
| `@weekly`   | Run once a week, same as `"0 0 * * 0"`                |
| `@yearly`   | Run once a year, same as `"0 0 1 1 *"` or `@annually` |

## Supported Notations

* [Oracle](https://docs.oracle.com/cd/E12058_01/doc/doc.1014/e12030/cron_expressions.htm)
* [Cron Format](http://www.nncron.ru/help/EN/working/cron-format.htm)
* [Wikipedia](https://en.wikipedia.org/wiki/Cron)

## Crontab Dependency

All Cron Expressions are parsed and evaluated by [crontab](https://hex.pm/packages/crontab).

Issues with parsing a cron expression can be reported here:
[crontab GitHub issues](https://github.com/jshmrtn/crontab/issues)
