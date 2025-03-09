# frozen_string_literal: true
require 'minitest/autorun'
require_relative '../lib/shipment_discount_calculator/price_table'
require_relative '../lib/shipment_discount_calculator/calculator'
require_relative '../lib/shipment_discount_calculator/input_processor'

class ShipmentDiscountCalculatorTest < Minitest::Test
    def setup
      # Create a temporary price table file for testing
      @price_table_file = 'test_shipping_price_table.txt'
      File.write(@price_table_file, <<~EOF)
            LP S 1.50 €
            LP M 4.90 €
            LP L 6.90 €
            MR S 2 €
            MR M 3 €
            MR L 4 €
      EOF
      @price_table = ShipmentDiscountCalculator::PriceTable.new(@price_table_file)
      @calculator = ShipmentDiscountCalculator::Calculator.new(@price_table)
    end

    def teardown
      File.delete(@price_table_file) if File.exist?(@price_table_file)
    end

    def test_price_table_loading
      assert_in_delta 1.50, @price_table.price('LP', 'S'), 0.001
      assert_in_delta 2.0,    @price_table.price('MR', 'S'), 0.001
      # The lowest price for S should be 1.50 (from LP)
      assert_in_delta 1.50, @price_table.lowest_price_for('S'), 0.001
    end

    def test_calculator_s_mr_shipment_discount
      # For an S shipment via MR: MR S price is 2.00, lowest S is 1.50, so discount is 0.50
      shipment = {
          date_str: '2015-02-01',
          date_components: { year: 2015, month: 2, day: 1 },
          size: 'S',
          provider: 'MR'
      }
      result = @calculator.calculate(shipment)
      assert_in_delta 0.50, result[:discount], 0.001
      assert_in_delta 1.50, result[:final_cost], 0.001
    end

    def test_calculator_s_lp_shipment_no_discount
      shipment = {
          date_str: '2015-02-02',
          date_components: { year: 2015, month: 2, day: 2 },
          size: 'S',
          provider: 'LP'
      }
      result = @calculator.calculate(shipment)
      assert_in_delta 1.50, result[:final_cost], 0.001
      assert_equal 0.0, result[:discount]
    end

    def test_calculator_invalid_shipment_missing_date_components
      shipment = { date_str: '2015-02-30', size: 'S', provider: 'MR' }
      result = @calculator.calculate(shipment)
      assert_nil result
    end

    def test_calculator_invalid_size
      shipment = {
          date_str: '2015-02-01',
          date_components: { year: 2015, month: 2, day: 1 },
          size: 'X',
          provider: 'MR'
      }
      result = @calculator.calculate(shipment)
      assert_nil result
    end

    def test_calculator_invalid_provider
      shipment = {
          date_str: '2015-02-01',
          date_components: { year: 2015, month: 2, day: 1 },
          size: 'S',
          provider: 'XX'
      }
      result = @calculator.calculate(shipment)
      assert_nil result
    end

    def test_calculator_lp_l_third_shipment_free
      # For LP L shipments, the first two have no discount, the third is free
      shipment1 = { date_str: '2015-03-01', date_components: { year: 2015, month: 3, day: 1 }, size: 'L', provider: 'LP' }
      shipment2 = { date_str: '2015-03-02', date_components: { year: 2015, month: 3, day: 2 }, size: 'L', provider: 'LP' }
      shipment3 = { date_str: '2015-03-03', date_components: { year: 2015, month: 3, day: 3 }, size: 'L', provider: 'LP' }
      result1 = @calculator.calculate(shipment1)
      result2 = @calculator.calculate(shipment2)
      result3 = @calculator.calculate(shipment3)
      assert_equal 0.0, result1[:discount]
      assert_equal 0.0, result2[:discount]
      assert_in_delta 6.90, result3[:discount], 0.001
      assert_in_delta 0.0, result3[:final_cost], 0.001
    end

    def test_calculator_monthly_discount_cap
      # For S shipments via MR, each discount is 0.50
      # After 20 shipments (20 * 0.50 = 10.00), further shipments get no discount
      @calculator = ShipmentDiscountCalculator::Calculator.new(@price_table) # reset
      results = []
      21.times do |i|
          date_str = format("2015-04-%02d", i + 1)
          shipment = {
            date_str: date_str,
            date_components: { year: 2015, month: 4, day: i + 1 },
            size: 'S',
            provider: 'MR'
          }
          results << @calculator.calculate(shipment)
      end

      20.times do |i|
          assert_in_delta 0.50, results[i][:discount], 0.001
          assert_in_delta 1.50, results[i][:final_cost], 0.001
      end

      assert_equal 0.0, results[20][:discount]
      assert_in_delta 2.00, results[20][:final_cost], 0.001
    end

    def test_input_processor_valid_line
      # Create a temporary input file
      input_file = 'test_input.txt'
      File.write(input_file, <<~EOF)
          2015-02-01 S MR
          2015-02-02 S LP
      EOF

      output = capture_io do
          processor = ShipmentDiscountCalculator::InputProcessor.new(@calculator, input_file)
          processor.process
      end.first

      expected_output = <<~EOF
          2015-02-01 S MR 1.50 0.50
          2015-02-02 S LP 1.50 -
      EOF
      assert_equal expected_output, output
    ensure
      File.delete(input_file) if File.exist?(input_file)
    end

    def test_input_processor_invalid_line
      input_file = 'test_input_invalid.txt'
      File.write(input_file, <<~EOF)
          2015-02-30 S MR
          2015-02-01 X MR
          2015-02-01 S XX
          2015-02-01 S
      EOF

      output = capture_io do
          processor = ShipmentDiscountCalculator::InputProcessor.new(@calculator, input_file)
          processor.process
      end.first

      expected_output = <<~EOF
          2015-02-30 S MR Ignored
          2015-02-01 X MR Ignored
          2015-02-01 S XX Ignored
          2015-02-01 S Ignored
      EOF
      assert_equal expected_output, output
    ensure
      File.delete(input_file) if File.exist?(input_file)
    end

    def test_parse_date_and_validations_in_input_processor
      # Testing the date parsing and validations via InputProcessor
      processor = ShipmentDiscountCalculator::InputProcessor.new(@calculator, 'nonexistent')
      # Call the private parse_date method via send
      valid_date = processor.send(:parse_date, '2020-02-29')
      assert_equal({ year: 2020, month: 2, day: 29 }, valid_date)

      invalid_date = processor.send(:parse_date, '2019-02-29')
      assert_nil invalid_date

      # Test leap year method
      assert processor.send(:leap_year?, 2020)
      refute processor.send(:leap_year?, 2019)
    end
end
