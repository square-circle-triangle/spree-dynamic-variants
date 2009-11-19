class DynamicVariantsExtension < Spree::Extension

  version "1.0"
  description "Generate variants from product options on the fly"
  url "http://github.com/square-circle-triangle/spree-dynamic-variants"

  def activate

    LineItem.class_eval do

      has_and_belongs_to_many :option_values

      validate :all_option_values_must_belong_to_product

      def all_option_values_must_belong_to_product
        unless option_values.all?{ |ov| variant.product.option_types.include?(ov.option_type) }
          errors.add(:option_values, "Incorrect product configuration: invalid option selected")
        end
      end

      def configuration_description
        option_values.map{ |ov| "#{ov.option_type.presentation}: #{ov.presentation}" }.join(', ')
      end

    end

    Order.class_eval do

      # Override this method to allow configuration to be stored and
      # so that a new line item is added each time even for the same product
      def add_variant(variant, quantity = 1, option_values = [])
        current_item = contains?(variant, option_values)
        if current_item
          current_item.increment_quantity unless quantity > 1
          current_item.quantity = (current_item.quantity + quantity) if quantity > 1
          current_item.save
        else
          current_item = LineItem.new(:quantity => quantity)
          current_item.variant = variant
          current_item.price   = variant.price + option_values.sum(&:price)

          current_item.option_values = option_values
          return nil unless current_item.save
          self.line_items << current_item
        end

        # populate line_items attributes for additional_fields entries
        # that have populate => [:line_item]
        Variant.additional_fields.select{|f| !f[:populate].nil? && f[:populate].include?(:line_item) }.each do |field|
          value = ""

          if field[:only].nil? || field[:only].include?(:variant)
            value = variant.send(field[:name].gsub(" ", "_").downcase)
          elsif field[:only].include?(:product)
            value = variant.product.send(field[:name].gsub(" ", "_").downcase)
          end
          current_item.update_attribute(field[:name].gsub(" ", "_").downcase, value)
        end

        current_item
      end

      # Override to check if a variant exists in order with the same product configuration
      def contains?(variant, option_values = [])
        line_items.select do |line_item|
          line_item.variant == variant and line_item.option_values.map(&:id).sort == option_values.map(&:id).sort
        end.first
      end

    end

    OrdersController.class_eval do
      create.after do
        params[:products].each do |product_id, variant_id|
          variant = Variant.find(variant_id)

          quantity = params[:quantity].to_i if !params[:quantity].is_a?(Array)
          quantity = params[:quantity][variant_id].to_i if params[:quantity].is_a?(Array)
          @order.add_variant(variant, quantity) if quantity > 0
        end if params[:products]

        params[:variants].each do |variant_id, quantity|
          variant = Variant.find(variant_id)

          quantity = quantity.to_i

          option_values = variant.product.option_types.inject([]) do |selected, ot|
            ov = ot.option_values.find(params[:variant_options][variant_id][ot.id.to_s]) if params[:variant_options][variant_id][ot.id.to_s]
            selected << ov if ov
          end if params[:variant_options] && params[:variant_options][variant_id]

          @order.add_variant(variant, quantity, option_values) if quantity > 0
        end if params[:variants]

        @order.save

        # store order token in the session
        session[:order_token] = @order.token
      end
    end

  end

end