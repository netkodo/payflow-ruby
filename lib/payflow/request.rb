require 'faraday'

module Payflow

  CARD_MAPPING = {
    :visa => 'Visa',
    :master => 'MasterCard',
    :discover => 'Discover',
    :american_express => 'Amex',
    :jcb => 'JCB',
    :diners_club => 'DinersClub',
    :switch => 'Switch',
    :solo => 'Solo'
  }

  TRANSACTIONS = {
    :sale           => "Sale",
    :authorization  => "Authorization",
    :capture        => "Capture",
    :void           => "Void",
    :credit         => "Credit"
  }

  DEFAULT_CURRENCY = "USD"

  XMLNS = 'http://www.paypal.com/XMLPay'

  class Request
    attr_accessor :xml

    TIMEOUT = 60

    TEST_URL = 'https://pilot-payflowpro.paypal.com'
    LIVE_URL = 'https://payflowpro.paypal.com'

    def initialize(action, money, credit_card_or_reference, options = {})
      @options = options
      self.xml = case action
      when :sale, :authorize
        build_sale_or_authorization_request(action, money, credit_card_or_reference, options)
      when :capture
        build_reference_request(action, money, credit_card_or_reference, options)
      when :void
        build_reference_request(action, money, credit_card_or_reference, options)
      end
    end

    def build_sale_or_authorization_request(action, money, credit_card_or_reference, options)
      if credit_card_or_reference.is_a?(String)
        build_reference_sale_or_authorization_request(action, money, credit_card_or_reference, options)
      else
        build_credit_card_request(action, money, credit_card_or_reference, options)
      end
    end

    def build_reference_sale_or_authorization_request(action, money, reference, options)
      xml = Builder::XmlMarkup.new
      xml.tag! TRANSACTIONS[action] do
        xml.tag! 'PayData' do
          xml.tag! 'Invoice' do
            # Fields accepted by PayFlow and recommended to be provided even for Reference Transaction, per Payflow docs.
            xml.tag! 'CustIP', options[:ip] unless options[:ip].blank?
            xml.tag! 'InvNum', options[:order_id].to_s.gsub(/[^\w.]/, '') unless options[:order_id].blank?
            xml.tag! 'Description', options[:description] unless options[:description].blank?
            xml.tag! 'Comment', options[:comment] unless options[:comment].blank?
            xml.tag!('ExtData', 'Name'=> 'COMMENT2', 'Value'=> options[:comment2]) unless options[:comment2].blank?
            xml.tag! 'TaxAmt', options[:taxamt] unless options[:taxamt].blank?
            xml.tag! 'FreightAmt', options[:freightamt] unless options[:freightamt].blank?
            xml.tag! 'DutyAmt', options[:dutyamt] unless options[:dutyamt].blank?
            xml.tag! 'DiscountAmt', options[:discountamt] unless options[:discountamt].blank?

            billing_address = options[:billing_address] || options[:address]
            add_address(xml, 'BillTo', billing_address, options) if billing_address
            add_address(xml, 'ShipTo', options[:shipping_address],options) if options[:shipping_address]

            xml.tag! 'TotalAmt', money, 'Currency' => options[:currency] || DEFAULT_CURRENCY
          end
          xml.tag! 'Tender' do
            xml.tag! 'Card' do
              xml.tag! 'ExtData', 'Name' => 'ORIGID', 'Value' =>  reference
            end
          end
        end
      end
      xml.target!
    end

    def build_credit_card_request(action, money, credit_card, options)
      xml = Builder::XmlMarkup.new
      xml.tag! TRANSACTIONS[action] do
        xml.tag! 'PayData' do
          xml.tag! 'Invoice' do
            xml.tag! 'CustIP', options[:ip] unless options[:ip].blank?
            xml.tag! 'InvNum', options[:order_id].to_s.gsub(/[^\w.]/, '') unless options[:order_id].blank?
            xml.tag! 'Description', options[:description] unless options[:description].blank?
            # Comment and Comment2 will show up in manager.paypal.com as Comment1 and Comment2
            xml.tag! 'Comment', options[:comment] unless options[:comment].blank?
            xml.tag!('ExtData', 'Name'=> 'COMMENT2', 'Value'=> options[:comment2]) unless options[:comment2].blank?
            xml.tag! 'TaxAmt', options[:taxamt] unless options[:taxamt].blank?
            xml.tag! 'FreightAmt', options[:freightamt] unless options[:freightamt].blank?
            xml.tag! 'DutyAmt', options[:dutyamt] unless options[:dutyamt].blank?
            xml.tag! 'DiscountAmt', options[:discountamt] unless options[:discountamt].blank?

            billing_address = options[:billing_address] || options[:address]
            add_address(xml, 'BillTo', billing_address, options) if billing_address
            add_address(xml, 'ShipTo', options[:shipping_address], options) if options[:shipping_address]

            xml.tag! 'TotalAmt', money, 'Currency' => options[:currency] || DEFAULT_CURRENCY
          end

          xml.tag! 'Tender' do
            add_credit_card(xml, credit_card)
          end
        end
      end
      xml.target!
    end

    def build_reference_request(action, money, authorization, options)
      xml = Builder::XmlMarkup.new
      xml.tag! TRANSACTIONS[action] do
        xml.tag! 'PNRef', authorization

        unless money.nil?
          xml.tag! 'Invoice' do
            xml.tag!('TotalAmt', money, 'Currency' => options[:currency] || DEFAULT_CURRENCY)
            xml.tag!('Description', options[:description]) unless options[:description].blank?
            xml.tag!('Comment', options[:comment]) unless options[:comment].blank?
            xml.tag!('ExtData', 'Name'=> 'COMMENT2', 'Value'=> options[:comment2]) unless options[:comment2].blank?
          end
        end
      end

      xml.target!
    end

    def add_credit_card(xml, credit_card)
      if credit_card.encrypted?
        add_encrypted_credit_card(xml, credit_card)
      else
        add_keyed_credit_card(xml, credit_card)
      end
    end

    def credit_card_type(credit_card)
      return '' if credit_card.brand.blank?

      CARD_MAPPING[credit_card.brand.to_sym]
    end

    def expdate(creditcard)
      year  = sprintf("%.4i", creditcard.year.to_s.sub(/^0+/, ''))
      month = sprintf("%.2i", creditcard.month.to_s.sub(/^0+/, ''))

      "#{year}#{month}"
    end

    def add_address(xml, tag, address, options)
      return if address.nil?
      xml.tag! tag do
        xml.tag! 'FirstName', address[:first_name] unless address[:first_name].blank?
        xml.tag! 'LastName', address[:last_name] unless address[:last_name].blank?
        xml.tag! 'EMail', options[:email] unless options[:email].blank?
        xml.tag! 'Phone', address[:phone] unless address[:phone].blank?
        xml.tag! 'CustCode', options[:customer] if !options[:customer].blank? && tag == 'BillTo'
        xml.tag! 'PONum', options[:po_number] if !options[:po_number].blank? && tag == 'BillTo'

        xml.tag! 'Address' do
          xml.tag! 'Street', address[:address1] unless address[:address1].blank?
          xml.tag! 'City', address[:city] unless address[:city].blank?
          xml.tag! 'State', address[:state].blank? ? "N/A" : address[:state]
          xml.tag! 'Country', address[:country] unless address[:country].blank?
          xml.tag! 'Zip', address[:zip] unless address[:zip].blank?
        end
      end
    end

    def commit(options = {})
      xml_body = build_request(xml)

      response = connection.post do |request|
        request.headers["Content-Type"] = "text/xml"
        request.headers["X-VPS-VIT-Integration-Product"] = "Payflow Gem"
        request.headers["X-VPS-VIT-Runtime-Version"] = RUBY_VERSION
        request.body = xml_body
      end

      Payflow::Response.new(response)
    end

    def test?
      return true
    end

    private
      def endpoint
        test? ? TEST_URL : LIVE_URL
      end

      def connection
        @conn ||= Faraday.new(:url => endpoint) do |faraday|
          faraday.request  :url_encoded
          faraday.response :logger
          faraday.adapter  Faraday.default_adapter
        end
      end

      def add_keyed_credit_card(xml, credit_card)
        xml.tag! 'Card' do
          xml.tag! 'CardType', credit_card_type(credit_card)
          xml.tag! 'CardNum', credit_card.number
          xml.tag! 'ExpDate', expdate(credit_card)
          xml.tag! 'NameOnCard', credit_card.first_name
          xml.tag! 'CVNum', credit_card.verification_value if credit_card.verification_value?
          xml.tag! 'ExtData', 'Name' => 'LASTNAME', 'Value' =>  credit_card.last_name
        end
      end

      def add_encrypted_credit_card(xml, credit_card)
        xml.tag! 'Card' do
          xml.tag! 'CardType', credit_card_type(credit_card)
          xml.tag! 'ExpDate', expdate(credit_card)
          xml.tag! 'NameOnCard', credit_card.first_name

          xml.tag! 'ExtData', 'Name' => 'LASTNAME', 'Value' =>  credit_card.last_name
          xml.tag! 'ExtData', 'Name' => 'ENCTRACK2', 'Value' => credit_card.enctrack2
          xml.tag! 'ExtData', 'Name' => 'ENCMP', 'Value' => credit_card.encmp
          xml.tag! 'ExtData', 'Name' => 'KSN', 'Value' => credit_card.ksn
          xml.tag! 'ExtData', 'Name' => 'MPSTATUS', 'Value' => credit_card.mpstatus
        end
      end

      def build_request(body, options = {})
        xml = Builder::XmlMarkup.new
        xml.instruct!

        xml.tag! 'XMLPayRequest', 'Timeout' => TIMEOUT.to_s, 'version' => "2.1", "xmlns" => XMLNS do
          xml.tag! 'RequestData' do
            xml.tag! 'Vendor', @options[:login]
            xml.tag! 'Partner', @options[:partner]
            if options[:request_type] == :recurring
              xml << body
            else
              xml.tag! 'Transactions' do
                xml.tag! 'Transaction', 'CustRef' => options[:customer] do
                  xml.tag! 'Verbosity', 'MEDIUM'
                  xml << body
                end
              end
            end
          end
          xml.tag! 'RequestAuth' do
            xml.tag! 'UserPass' do
              xml.tag! 'User', !@options[:user].blank? ? @options[:user] : @options[:login]
              xml.tag! 'Password', @options[:password]
            end
          end
        end
        xml.target!
      end
  end
end