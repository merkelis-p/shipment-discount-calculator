# frozen_string_literal: true
#
# This class implements the shipment discount calculation logic
#
# It applies these rules:
#
# - For S shipments via MR, the discount equals the difference between the MR S price
#   and the lowest S price (computed from the price table)
#
# - For L shipments via LP, the third LP L shipment in a calendar month is free
#
# - In any calendar month, the total discount cannot exceed 10.00 €
#
# The Calculator uses a PriceTable instance for looking up prices and valid values
# It assumes that the shipment hash already contains a valid :date_components key
#
module ShipmentDiscountCalculator
    class Calculator
      MAX_MONTHLY_DISCOUNT = 10.00
  
      def initialize(price_table)
        @price_table = price_table
        # @monthly_data is keyed by "YYYY-MM" and stores:
        #   :discount   => cumulative discount given in that month
        #   :lp_l_count => count of LP shipments for package L in that month
        @monthly_data = {}
      end
  
      # Expects shipment to be a hash with keys:
      #   :date_str       => String date (e.g. "2015-02-01")
      #   :date_components=> Hash with keys :year, :month, :day (provided by the input processor)
      #   :size           => Package size (e.g. "S", "M", "L")
      #   :provider       => Provider code (e.g. "LP", "MR")
      #
      # Returns a hash:
      #   { cost: Float, discount: Float, final_cost: Float }
      #
      # Returns nil if validation fails
      def calculate(shipment)
        date_components = shipment[:date_components]
        return nil if date_components.nil?
  
        size     = shipment[:size]
        provider = shipment[:provider]
        date_str = shipment[:date_str]
  
        # Validate against the price table (providers and sizes are loaded from file)
        return nil unless @price_table.sizes.include?(size) && @price_table.providers.include?(provider)
  
        cost = @price_table.price(provider, size)
        return nil if cost.nil?
  
        potential = potential_discount(date_components, size, provider, cost)
        month_key = format('%04d-%02d', date_components[:year], date_components[:month])
        current = monthly_data(month_key)[:discount]
        available = MAX_MONTHLY_DISCOUNT - current
        discount_to_apply = available.positive? ? [potential, available].min : 0.0
  
        update_monthly_data(date_components, size, provider, discount_to_apply, month_key)
  
        final_cost = (cost - discount_to_apply).round(2)
        { cost: cost, discount: discount_to_apply, final_cost: final_cost }
      end
  
      private
  
      def monthly_data(month_key)
        @monthly_data[month_key] ||= { discount: 0.0, lp_l_count: 0 }
      end
  
      # Computes the potential discount for a shipment
      def potential_discount(date_components, size, provider, cost)
        if size == 'S' && provider == 'MR'
          lowest = @price_table.lowest_price_for('S')
          return (cost - lowest).round(2) if lowest && cost > lowest
        end
  
        if size == 'L' && provider == 'LP'
          month_key = format('%04d-%02d', date_components[:year], date_components[:month])
          return cost if monthly_data(month_key)[:lp_l_count] == 2
        end
  
        0.0
      end
  
      def update_monthly_data(date_components, size, provider, discount_applied, month_key)
        data = monthly_data(month_key)
        data[:discount] += discount_applied
        data[:lp_l_count] += 1 if size == 'L' && provider == 'LP'
      end
    end
end
  