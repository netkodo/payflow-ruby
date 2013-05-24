require 'ostruct'
require 'spec_helper'

describe Payflow::Gateway do
  describe "Making a Sale" do
    it "should require a login and password" do
#      credit_card = Payflow::CreditCard.new(name: "Doctor Jones", number: "4111111111111111", month: "11", year: "2020")
#      gateway = Payflow::Gateway.new(partner: "Paypal", login: "", password: "")

      #.new(duck)
      #response = gateway.sale(100, credit_card)
    end
  end

  describe "Initializing" do
    it "should require login" do
      gateway = Payflow::Gateway.new(OpenStruct.new(password: "password", partner: "partner"))
      gateway.should be(nil)
    end

    it "should require password" do
      gateway = Payflow::Gateway.new(OpenStruct.new(login: "login", partner: "partner"))
      gateway.should be(nil)
    end

    it "should require partner" do
      gateway = Payflow::Gateway.new(OpenStruct.new(password: "password",  login: "login"))
      gateway.should be(nil)
    end

    it "should be valid with login, password, partner" do
      gateway = Payflow::Gateway.new(OpenStruct.new(password: "password",  login: "login", partner: "Partner"))
      gateway.should be_a(Payflow::Gateway)
    end
  end
end