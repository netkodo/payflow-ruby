require 'active_model'
require 'credit_card_validator'

module Payflow
  class CreditCard
    include ActiveModel::Validations
    validates_with CustomCreditCardValidator

    attr_accessor :number
    attr_accessor :month
    attr_accessor :year
    attr_accessor :brand
    attr_accessor :first_name
    attr_accessor :last_name
    attr_accessor :security_code
    attr_accessor :encrypted_track_data
    attr_accessor :last_four_digits

    attr_accessor :track2
    attr_accessor :mp
    attr_accessor :ksn
    attr_accessor :mpstatus
    attr_accessor :device_sn

    attr_accessor :billing_first_name
    attr_accessor :billing_last_name
    attr_accessor :billing_street
    attr_accessor :billing_street2
    attr_accessor :billing_city
    attr_accessor :billing_state
    attr_accessor :billing_zip
    attr_accessor :billing_country

    attr_accessor :shipping_first_name
    attr_accessor :shipping_last_name
    attr_accessor :shipping_street
    attr_accessor :shipping_city
    attr_accessor :shipping_state
    attr_accessor :shipping_zip
    attr_accessor :shipping_zip
    attr_accessor :shipping_country


    def initialize(options = {})
      @number = options[:number]
      @month  = options[:month]
      @year   = options[:year]
      @first_name = options[:first_name]
      @last_name  = options[:last_name]
      @security_code = options[:security_code]
      @encrypted_track_data = options[:encrypted_track_data]

      self.track2    = options[:track2]
      self.mpstatus  = options[:mpstatus]
      self.device_sn = options[:device_sn]
      self.ksn       = options[:ksn]
      self.mp        = options[:mp]

      parse_encryption if encrypted_string?
      set_brand(@number) if @number
    end

    def add_address(options = {})
      @billing_first_name   = options[:billing_first_name]
      @billing_last_name    = options[:billing_last_name]
      @billing_street       = options[:billing_street]
      @billing_street2      = options[:billing_street2]
      @billing_city         = options[:billing_city]
      @billing_state        = options[:billing_state]
      @billing_zip          = options[:billing_zip]
      @billing_country      = options[:billing_country]

      @shipping_first_name  = options[:shipping_first_name]
      @shipping_last_name   = options[:shipping_last_name]
      @shipping_street      = options[:shipping_street]
      @shipping_city        = options[:shipping_city]
      @shipping_state       = options[:shipping_state]
      @shipping_zip         = options[:shipping_zip]
      @shipping_country     = options[:shipping_country]
    end

    def expiry_date
      ExpiryDate.new(@month, @year)
    end

    def expired?
      expiry_date.expired?
    end

    def encrypted?
      encrypted_params? or encrypted_string?
    end

    def encrypted_params?
      track2.present? and mpstatus.present? and device_sn.present? and ksn.present? and mp.present?
    end

    def encrypted_string?
      encrypted_track_data.present?
    end

    def display_number
      self.class.mask(number)
    end

    def name
      "#{first_name} #{last_name}"
    end

    def last_four
      @last_four_digits ||= self.class.last_digits(number)
    end

    def self.mask(number)
      "XXXX-XXXX-XXXX-#{last_digits(number)}"
    end

    def self.last_digits(number)
      number.to_s.length <= 4 ? number : number.to_s.slice(-4..-1)
    end

    private
      def set_brand(brand_designator)
        self.brand = translate_card(CreditCardValidator::Validator.card_type(brand_designator))
      end

      def translate_card(card)
        return :master if card == "master_card"
        card.to_sym
      rescue
        ""
      end

      def parse_encryption
        data = encrypted_track_data.split('|')
        self.track2 = data[3]
        self.mpstatus = data[5]
        self.mp = data[6]
        self.device_sn = data[7]
        self.ksn = data[9]

        split = encrypted_track_data.slice(2, encrypted_track_data.length-2).split("^")
        set_brand(split[0]) if split[0]
        @last_four_digits = split[0].slice(-4, 4) if split[0]
        if split[1]
          self.first_name = split[1].split("/").last
          self.last_name = split[1].split("/").first
        end
      end

  end
end
