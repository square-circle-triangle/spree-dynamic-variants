module DynamicVariantsHelper

  def option_values_for_select(option_type)
    options_for_select(option_type.option_values.collect{ |ov| [option_value_format(ov), ov.id] })
  end

  def option_value_format(option_value)
    "#{option_value.presentation} #{format_price_difference(option_value.price)}"
  end

  def format_price_difference(value)
    if value == 0.0
      return ''
    elsif value > 0
      prefix = '+'
    else
      prefix = '-'
    end
    "(#{prefix}#{format_price(value, :show_vat_text => false)})"
  end

end