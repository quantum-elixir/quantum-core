defmodule Quantum.DateLibraryTest do
  use ExUnit.Case, async: true

  @implementations [Quantum.DateLibrary.Timex, Quantum.DateLibrary.Calendar]

  for module <- @implementations do
    @module module

    describe Atom.to_string(@module) <> ".utc_to_tz!/2" do
      test "shifts zone" do
        date = ~N[2015-01-01 01:00:00]
        expected = ~N[2015-01-01 02:00:00]

        assert @module.utc_to_tz!(date, "Europe/Copenhagen") == expected
      end
    end

    describe Atom.to_string(@module) <> ".tz_to_utc!/2" do
      test "shifts zone" do
        date = ~N[2015-01-01 02:00:00]
        expected = ~N[2015-01-01 01:00:00]

        assert @module.tz_to_utc!(date, "Europe/Copenhagen") == expected
      end
    end
  end
end
