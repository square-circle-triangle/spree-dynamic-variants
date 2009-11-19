class CreateLineItemsOptionValues < ActiveRecord::Migration

  def self.up
    create_table :line_items_option_values, :id => false do |t|
      t.integer :line_item_id
      t.integer :option_value_id
    end
  end

  def self.down
    drop_table :line_items_option_values
  end

end