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
      request = Payflow::Request.new(:sale, money, credit_card_or_reference, options)

      request.commit(options)
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

    private

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

  end
end