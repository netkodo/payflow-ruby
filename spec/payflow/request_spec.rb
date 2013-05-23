require 'spec_helper'
require "nokogiri"

describe Payflow::Request do
  describe "initializing" do
    it "should build a sale request on action capture" do
      request = Payflow::Request.new(:sale, 100, "CREDITCARDREF")
      doc = Nokogiri::XML(request.xml)

      doc.xpath("/Sale").length.should be(1)
    end

    it "should build a capture request on action capture" do
      request = Payflow::Request.new(:capture, 100, "CREDITCARDREF")
      doc = Nokogiri::XML(request.xml)

      doc.xpath("/Capture").length.should be(1)
    end

    describe "with an encrypted credit_card" do
      it "should add ENCTRACK2 to the request xml" do
        credit_card = Payflow::CreditCard.new(encrypted_track_data: "SUPERENCRYPTEDTRACKDATA")
        request = Payflow::Request.new(:sale, 100, credit_card)
        doc = Nokogiri::XML(request.xml)
        doc.xpath("//Card/ExtData[@Name='ENCTRACK2']").length.should be(1)
      end
    end
  end
end