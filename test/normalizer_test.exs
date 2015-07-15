defmodule Quantum.NormalizerTest do
  use ExUnit.Case

  import Quantum.Normalizer

  test "normalize" do
    assert normalize({"0", nil}) == {"0", nil}
    assert normalize({"A", nil}) == {"a", nil}
    assert normalize({"jan", nil}) == {"1", nil}
    assert normalize({:atom, nil}) == {"atom", nil}
    assert normalize("* * * * * MyApp.MyModule.my_method") == {"* * * * *", {"MyApp.MyModule", :my_method}}
  end

end
