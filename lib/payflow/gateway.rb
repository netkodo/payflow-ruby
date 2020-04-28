module Payflow

  class Gateway

    attr_accessor :login, :partner, :password, :user

    def self.new(merchant_account, options = {})
      super if requires!(merchant_account, :login, :password, :partner, :user)
    end

    def initialize(merchant_account, options = {})
      @login = merchant_account.login
      @partner = merchant_account.partner
      @password = merchant_account.password
      @user = merchant_account.user

      @options = options.merge({
        login: login,
        password: password,
        partner: partner,
        user: user
      })
    end

    def request(action, money, credit_card_or_reference, options)
      Payflow::Request.new(action, money, credit_card_or_reference, options.merge(@options))
    end

    def authorize(money, credit_card_or_reference, options = {})
      request(:authorization, money, credit_card_or_reference, options).commit(options)
    end

    def sale(money, credit_card_or_reference, options = {})
      request(:sale, money, credit_card_or_reference, options).commit(options)
    end

    def refund(money, reference, options = {})
      request(:credit, money, reference, options).commit(options)
    end

    def credit(money, credit_card, options = {})
      request(:credit, money, credit_card, options).commit(options)
    end

    def capture(money, authorization, options = {})
      request(:capture, money, authorization, options).commit(options)
    end

    def void(authorization, options = {})
      request(:void, nil, authorization, options).commit(options)
    end

    def inquire(authorization, options = {})
      request(:inquire, nil, authorization, options).commit(options)
    end

    def store_card(credit_card)
      response = authorize(1,
            credit_card,
            { pairs: { comment1: "VERIFY" } }
      )

      if response.successful?
        void(response.token)
      end

      response
    end

    private
      def self.requires!(object, *required_fields)
        required_fields.each do |field|
          return false unless object.respond_to?(field)
        end
        true
      end
  end
end
