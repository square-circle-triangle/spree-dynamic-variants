jQuery(document).ready(function($) {

  $('#cart-form .affects-price').change(function(){

    data = $('#cart-form form').serializeArray();

    $.get(update_configuration_price_url, data, null, 'script');

  })

});