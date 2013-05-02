require 'spec_helper'

describe Payflow::CreditCard do
  it "should know how to mask a card number" do
    number = "1234567890123456"
    Payflow::CreditCard.mask(number).should eql("XXXX-XXXX-XXXX-3456")
  end
end