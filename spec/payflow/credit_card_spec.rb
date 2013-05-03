require 'spec_helper'

describe Payflow::CreditCard do
  it "should know how to mask a card number" do
    number = "1234567890123456"
    Payflow::CreditCard.mask(number).should eql("XXXX-XXXX-XXXX-3456")
  end

  it "should know if the card is not expired" do
    valid_card = Payflow::CreditCard.new(
      number: "4111111111111111",
      month: "1",
      year: "2090",
      first_name: "Steve",
      last_name: "McQueen"
      )
    valid_card.expired?.should be(false)
  end

  it "should know if the card is expired" do
    expired_card = Payflow::CreditCard.new(
      number: "4111111111111111",
      month: "1",
      year: "2011",
      first_name: "Steve",
      last_name: "McQueen"
      )
    expired_card.expired?.should be(true)
  end
end