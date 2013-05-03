module Payflow
  class Gateway

    def initialize(options = {})
      requires!(options, :login, :password)

      options[:partner] = partner if options[:partner].blank?
      super
    end
    
    def connection
    end

    def authorize
      request = build_sale_or_authorization_request(:authorization, money, credit_card_or_reference, options)

      commit(request, options)
    end

    def sale(money, credit_card_or_reference, options = {})
      request = build_sale_or_authorization_request(:purchase, money, credit_card_or_reference, options)

      commit(request, options)
    end

    def credit(money, identification_or_credit_card, options = {})
      if identification_or_credit_card.is_a?(String)
        deprecated CREDIT_DEPRECATION_MESSAGE
        # Perform referenced credit
        refund(money, identification_or_credit_card, options)
      else
        # Perform non-referenced credit
        request = build_credit_card_request(:credit, money, identification_or_credit_card, options)
        commit(request, options)
      end
    end

    def refund(money, reference, options = {})
      commit(build_reference_request(:credit, money, reference, options), options)
    end

    
    

    def capture(money, authorization, options = {})
      request = build_reference_request(:capture, money, authorization, options)
      commit(request, options)
    end

    def void(authorization, options = {})
      request = build_reference_request(:void, nil, authorization, options)
      commit(request, options)
    end

    def sale
    end


    private

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

            xml.tag! 'TotalAmt', amount(money), 'Currency' => options[:currency] || currency(money)
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

            xml.tag! 'TotalAmt', amount(money), 'Currency' => options[:currency] || currency(money)
          end

          xml.tag! 'Tender' do
            add_credit_card(xml, credit_card)
          end
        end
      end
      xml.target!
    end

    def add_credit_card(xml, credit_card)
      xml.tag! 'Card' do
        xml.tag! 'CardType', credit_card_type(credit_card)
        xml.tag! 'CardNum', credit_card.number
        xml.tag! 'ExpDate', expdate(credit_card)
        xml.tag! 'NameOnCard', credit_card.first_name
        xml.tag! 'CVNum', credit_card.verification_value if credit_card.verification_value?

        if requires_start_date_or_issue_number?(credit_card)
          xml.tag!('ExtData', 'Name' => 'CardStart', 'Value' => startdate(credit_card)) unless credit_card.start_month.blank? || credit_card.start_year.blank?
          xml.tag!('ExtData', 'Name' => 'CardIssue', 'Value' => format(credit_card.issue_number, :two_digits)) unless credit_card.issue_number.blank?
        end
        xml.tag! 'ExtData', 'Name' => 'LASTNAME', 'Value' =>  credit_card.last_name
      end
    end

    def credit_card_type(credit_card)
      return '' if card_brand(credit_card).blank?

      CARD_MAPPING[card_brand(credit_card).to_sym]
    end

    def expdate(creditcard)
      year  = sprintf("%.4i", creditcard.year.to_s.sub(/^0+/, ''))
      month = sprintf("%.2i", creditcard.month.to_s.sub(/^0+/, ''))

      "#{year}#{month}"
    end

    def build_request(body, options = {})
      xml = Builder::XmlMarkup.new
      xml.instruct!
      xml.tag! 'XMLPayRequest', 'Timeout' => timeout.to_s, 'version' => "2.1", "xmlns" => XMLNS do
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

    def build_reference_request(action, money, authorization, options)
      xml = Builder::XmlMarkup.new
      xml.tag! TRANSACTIONS[action] do
        xml.tag! 'PNRef', authorization

        unless money.nil?
          xml.tag! 'Invoice' do
            xml.tag!('TotalAmt', amount(money), 'Currency' => options[:currency] || currency(money))
            xml.tag!('Description', options[:description]) unless options[:description].blank?
            xml.tag!('Comment', options[:comment]) unless options[:comment].blank?
            xml.tag!('ExtData', 'Name'=> 'COMMENT2', 'Value'=> options[:comment2]) unless options[:comment2].blank?
          end
        end
      end

      xml.target!
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

    def parse(data)
      response = {}
      xml = Nokogiri::XML(data)
      xml.remove_namespaces!
      root = xml.xpath("//ResponseData")

      tx_result = root.xpath(".//TransactionResult").first

      if tx_result && tx_result.attributes['Duplicate'].to_s == "true"
        response[:duplicate] = true
      end

      root.xpath(".//*").each do |node|
        parse_element(response, node)
      end

      response
    end

    def build_headers(content_length)
      {
        "Content-Type" => "text/xml",
        "Content-Length" => content_length.to_s,
        "X-VPS-Client-Timeout" => timeout.to_s,
        "X-VPS-VIT-Integration-Product" => "Bypass",
        "X-VPS-VIT-Runtime-Version" => RUBY_VERSION,
        "X-VPS-Request-ID" => Utils.generate_unique_id
      }
    end

    def commit(request_body, options  = {})
      request = build_request(request_body, options)
      headers = build_headers(request.size)

      response = parse(ssl_post(test? ? self.test_url : self.live_url, request, headers))

      build_response(response[:result] == "0", response[:message], response,
        :test => test?,
        :authorization => response[:pn_ref] || response[:rp_ref],
        :cvv_result => CVV_CODE[response[:cv_result]],
        :avs_result => { :code => response[:avs_result] }
      )
    end

  end
end