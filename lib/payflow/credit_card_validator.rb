require 'active_model'

module Payflow
  class CreditCard
    class CreditCardValidator < ActiveModel::Validator
      attr_accessor :record

      def validate(record)
        @record = record
        validate_card_number
      end

      def validate_card_number
        if record.number.blank?
          record.errors.add :number, "is required"
        elsif !CreditCard.valid_number?(number)
          record.errors.add :number, "is not a valid credit card number"
        elsif !CreditCard.matching_brand?(number, brand)
          record.errors.add :brand, "does not match the card number"
        end
      end

      def validate_card_brand #:nodoc:
        record.errors.add :brand, "is required" if record.brand.blank? && record.number.present?
        record.errors.add :brand, "is invalid"  unless record.brand.blank? || CreditCard.card_companies.keys.include?(brand)
      end
    end
  end
end