defmodule Quantum.TranslatorTest do
  use ExUnit.Case

  import Quantum.Translator

  test "translates weekday names" do
    assert translate("sun") == "0"
    assert translate("mon") == "1"
    assert translate("tue") == "2"
    assert translate("wed") == "3"
    assert translate("thu") == "4"
    assert translate("fri") == "5"
    assert translate("sat") == "6"
  end 

  test "translates month names" do
    assert translate("jan") == "1"
    assert translate("feb") == "2"
    assert translate("mar") == "3"
    assert translate("apr") == "4"
    assert translate("may") == "5"
    assert translate("jun") == "6"
    assert translate("jul") == "7"
    assert translate("aug") == "8"
    assert translate("sep") == "9"
    assert translate("oct") == "10"
    assert translate("nov") == "11"
    assert translate("dec") == "12"
  end
  
  test "translates all occurrencies in a string" do
    assert translate("jan,feb,mar,apr,may,jun") == "1,2,3,4,5,6"
    assert translate("jul,aug,sep,oct,nov,dec") == "7,8,9,10,11,12"
    assert translate("sun,mon,tue,wed,thu,fri,sat") == "0,1,2,3,4,5,6"
  end

end
