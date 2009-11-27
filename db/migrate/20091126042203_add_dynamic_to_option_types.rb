class AddDynamicToOptionTypes < ActiveRecord::Migration

  def self.up
    add_column :option_types, :dynamic, :boolean, :default => 0
  end

  def self.down
    remove_column :option_types, :dynamic
  end

end