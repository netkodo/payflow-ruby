require 'active_model'

module Payflow
  class CreditCard
    include ::ActiveModel::Validations

    attr_accessor :number
    attr_accessor :month
    attr_accessor :year
    attr_accessor :brand
    attr_accessor :first_name
    attr_accessor :last_name
    attr_accessor :security_code

    def initialize(options = {})
      @number = options[:number]
      @month  = options[:month]
      @year   = options[:year]
    end

    def valid?
    end

    def expiry_date
      ExpiryDate.new(@month, @year)
    end

    def expired?
      expiry_date.expired?
    end

    def display_number
      self.class.mask(number)
    end

    def self.mask(number)
      "XXXX-XXXX-XXXX-#{last_digits(number)}"
    end

    def self.last_digits(number)
      number.to_s.length <= 4 ? number : number.to_s.slice(-4..-1)
    end

    def validate_card_number
      if number.blank?
        errors.add :number, "is required"
      elsif !CreditCard.valid_number?(number)
        errors.add :number, "is not a valid credit card number"
      end

      unless errors.on(:number) || errors.on(:brand)
        errors.add :brand, "does not match the card number" unless CreditCard.matching_brand?(number, brand)
      end
    end

    def validate_card_brand #:nodoc:
      errors.add :brand, "is required" if brand.blank? && number.present?
      errors.add :brand, "is invalid"  unless brand.blank? || CreditCard.card_companies.keys.include?(brand)
    end

    alias_method :validate_card_type, :validate_card_brand
  end
end