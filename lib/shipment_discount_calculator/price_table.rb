# frozen_string_literal: true
#
# This class loads the shipping price table from a text file
# Each non-empty line should contain three fields (separated by whitespace):
#
#  Provider  Size  Price
#
#  LP        S   1.50 €
#  MR        L   4 €
#
# The prices are stored in a nested hash { provider => { size => price } }
#
module ShipmentDiscountCalculator
    class PriceTable
      attr_reader :prices
    
      def initialize(file_path)
        @prices = {}
        load_prices(file_path)
      end
    
      # Returns the price for the given provider and package size
      def price(provider, size)
        @prices[provider]&.[](size)
      end
    
      # Returns an array of valid provider codes from the file
      def providers
        @prices.keys
      end
    
      # Returns an array of valid package sizes from the file
      def sizes
        @prices.values.map(&:keys).flatten.uniq
      end
    
      # Returns the lowest price among all providers for the given package size
      def lowest_price_for(size)
        candidates = @prices.values.map { |h| h[size] }.compact
        candidates.min
      end
    
      private
    
      def load_prices(file_path)
        File.foreach(file_path) do |line|
          next if line.strip.empty?
          parts = line.strip.split
          # Expect at least three parts: provider, size, price
          next unless parts.size >= 3
          provider, size, price_str = parts[0], parts[1], parts[2]
          # Remove the euro symbol character
          numeric_price = price_str.gsub(/[^\d.]/, '').to_f
          @prices[provider] ||= {}
          @prices[provider][size] = numeric_price
        end
      end
    end
  end
    