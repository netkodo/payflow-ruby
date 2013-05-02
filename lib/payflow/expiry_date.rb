module Payflow
  class CreditCard
    class ExpiryDate
      attr_reader :month, :year

      def initialize(month, year)
        @month = month.to_i
        @year = year.to_i
      end

      def expired?
        Time.now.utc > expiration
      end

      def expiration
        Time.utc(year, month, last_day_of_month, 23, 59, 59)
      rescue ArgumentError
        Time.at(0).utc
      end

      private
        def last_day_of_month
          mdays = [nil,31,28,31,30,31,30,31,31,30,31,30,31]
          mdays[2] = 29 if Date.leap?(year)
          mdays[month]
        end
    end
  end
end