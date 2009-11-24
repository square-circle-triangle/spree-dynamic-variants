module DynamicVariantsHelper

  def option_values_for_select(option_type)
    options_for_select(option_type.option_values.collect{ |ov| ["#{ov.presentation} #{format_price_difference(ov.price)}", ov.id] })
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