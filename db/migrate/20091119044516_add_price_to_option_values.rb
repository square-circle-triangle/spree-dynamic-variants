class AddPriceToOptionValues < ActiveRecord::Migration

  def self.up
    add_column :option_values, :price, :decimal, :precision => 8, :scale => 2, :default => 0.00
  end

  def self.down
    remove_column :option_values, :price
  end

end