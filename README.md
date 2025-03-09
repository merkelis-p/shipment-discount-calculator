# Shipment Discount Calculator

This project implements a shipping discount calculation module for a fictional shipping system. It reads shipment transactions from an input file and applies discount rules based on a configurable shipping price table

## Overview

The calculator applies the following rules:
- S Shipments (Small Packages): for shipments sent via MR, the discount equals the difference between the MR price and the lowest S price (found dynamically among all providers)
- L Shipments (Large Packages): for shipments via LP, the third shipment in a given month (tracked by year and month) is free
- Monthly Discount Cap: in any calendar month, the total discount cannot exceed €10.00

The design is modular:
- PriceTable: Loads shipping prices including valid providers and sizes from an external text file
- Calculator: Performs discount computations using the loaded price table
- InputProcessor: Parses shipment input files, including date validation with leap-year support, and delegates calculations to the Calculator
- Executable: A command-line tool `bin/run` that ties everything together

## File Structure

```
.
├── bin
│   └── run                       # Main executable script
├── data
│   ├── input.txt                 # Sample input file
│   └── price_table.txt           # Price table configuration file
├── lib
│   └── shipment_discount_calculator
│       ├── calculator.rb         # Core discount calculation logic
│       ├── input_processor.rb    # Input parsing and processing
│       └── price_table.rb        # Loads shipping prices from file
└── test
    └── shipment_discount_calculator_test.rb  # Minitest tests
```

## Usage

1. Requirements:  
   Ensure you have Ruby installed

2. Running the Application:  
   From the project root, run:
   ```
   ruby bin/run data/input.txt data/price_table.txt
   ```
   If no arguments are provided, the program defaults to `data/input.txt` and `data/price_table.txt`

3. Running the Tests:  
   Execute the test suite with:
   ```
   ruby test/shipment_discount_calculator_test.rb
   ```
