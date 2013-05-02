require 'spec_helper'

describe "ExpiryDate" do
  it "should expire" do
    at_least_last_month = Time.now - 3600 * 24 * 31
    date = Payflow::CreditCard::ExpiryDate.new(at_least_last_month.month, at_least_last_month.year)
    date.expired?.should be(true)
  end

  it "should not be expired today" do
    time = Time.now
    date = Payflow::CreditCard::ExpiryDate.new(time.month, time.year)
    date.expired?.should be(false)
  end

  it "should handle bad date arguments" do
    date = Payflow::CreditCard::ExpiryDate.new(13, 2013)
    date.expiration.should eql(Time.at(0).utc)
  end
end