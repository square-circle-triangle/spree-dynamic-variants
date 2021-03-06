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

      def price_with_options(option_values)
        self.price + option_values.sum(&:price)
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
          current_item               = LineItem.new(:quantity => quantity)
          current_item.variant       = variant
          current_item.price         = variant.price_with_options(option_values)
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
            selected
          end if params[:variant_options] && params[:variant_options][variant_id]

          @order.add_variant(variant, quantity, option_values) if quantity > 0
        end if params[:variants]

        @order.save

        # store order token in the session
        session[:order_token] = @order.token
      end
    end

    ProductsController.class_eval do

      helper :dynamic_variants

      def update_configuration_price
        @new_price = nil

        params[:variants].each do |variant_id, quantity|
          variant = Variant.find(variant_id)

          quantity = quantity.to_i

          option_values = variant.product.option_types.inject([]) do |selected, ot|
            ov = ot.option_values.find(params[:variant_options][variant_id][ot.id.to_s]) if params[:variant_options][variant_id][ot.id.to_s]
            selected << ov if ov
            selected
          end if params[:variant_options] && params[:variant_options][variant_id]

          @new_price = variant.price_with_options(option_values)
        end if params[:variants]

        render :action => 'update_configuration_price', :layout => false
      end

    end

    Product.class_eval do

      has_many :product_option_types, :dependent => :destroy do
        def static(*args)
          with_scope(:find => { :conditions => {"option_types.dynamic" => false }, :include => :option_type }) do
            all(*args)
          end
        end

        def dynamic(*args)
          with_scope(:find => { :conditions => {"option_types.dynamic" => true }, :include => :option_type }) do
            all(*args)
          end
        end
      end

      alias :options :product_option_types

      has_many :option_types, :through => :product_option_types do
        def static(*args)
          with_scope(:find => { :conditions => { :dynamic => false }, :include => :option_values }) do
            all(*args)
          end
        end

        def dynamic(*args)
          with_scope(:find => { :conditions => { :dynamic => true }, :include => :option_values }) do
            all(*args)
          end
        end
      end

    end

  end

end