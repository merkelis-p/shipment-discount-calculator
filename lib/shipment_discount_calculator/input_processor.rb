# frozen_string_literal: true
#
# This class is responsible for reading an input file containing shipment transactions
#
# Each line is expected to have three tokens:
#  Date  PackageSize Provider
#
# The InputProcessor parses each line – it validates and extracts the date,
# package size, and provider. It uses its own date-parsing, valid-date, and leap-year methods
# If a line is invalid, it appends "Ignored" to that line
#
# It then passes valid shipment hashes to the Calculator
#
module ShipmentDiscountCalculator
    class InputProcessor
      def initialize(calculator, input_file)
        @calculator = calculator
        @input_file = input_file
      end
    
      # Reads the input file line by line, processes each non-empty line, and prints the result to stdout
      def process
        File.foreach(@input_file) do |line|
          next if line.strip.empty?
          puts process_line(line)
        end
      end
    
      private
    
      # Processes a single line
      def process_line(line)
        shipment = parse_shipment_line(line)
        result = shipment && @calculator.calculate(shipment)
        return "#{line.strip} Ignored" if shipment.nil? || result.nil?
    
        cost      = result[:cost]
        discount  = result[:discount]
        final_cost = result[:final_cost]
        cost_str  = format('%.2f', final_cost)
        discount_str = discount.positive? ? format('%.2f', discount) : '-'
        "#{shipment[:date_str]} #{shipment[:size]} #{shipment[:provider]} #{cost_str} #{discount_str}"
      end
    
      # Splits the line and validates each token
      # Returns a shipment hash (with :date_components added) or nil if invalid
      def parse_shipment_line(line)
        tokens = line.strip.split
        return nil unless tokens.size == 3
    
        date_str, size, provider = tokens
        date_components = parse_date(date_str)
        return nil if date_components.nil?
    
        # Validate using price table from calculator
        valid_sizes = @calculator.instance_variable_get(:@price_table).sizes
        valid_providers = @calculator.instance_variable_get(:@price_table).providers
    
        return nil unless valid_sizes.include?(size) && valid_providers.include?(provider)
    
        { date_str: date_str, date_components: date_components, size: size, provider: provider }
      end
    
      # Parses a date string in "YYYY-MM-DD" format
      # Returns a hash { year: YYYY, month: MM, day: DD} if valid, otherwise nil
      def parse_date(date_str)
        if date_str =~ /^(\d{4})-(\d{2})-(\d{2})$/
          year  = Regexp.last_match(1).to_i
          month = Regexp.last_match(2).to_i
          day  = Regexp.last_match(3).to_i
          return nil unless valid_date?(year, month, day)
          { year: year, month: month, day: day }
        else
          nil
        end
      end
    
      # Returns true if the given year, month, and day form a valid date
      def valid_date?(year, month, day)
        return false unless month.between?(1, 12)
        days_in_month = case month
                        when 2 then leap_year?(year) ? 29 : 28
                        when 4, 6, 9, 11 then 30
                        else 31
                        end
        day.between?(1, days_in_month)
      end
    
      # Returns true if the given year is a leap year
      def leap_year?(year)
        (year % 4).zero? && (!(year % 100).zero? || (year % 400).zero?)
      end
    end
  end
    