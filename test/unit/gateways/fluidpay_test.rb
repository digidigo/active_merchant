require 'test_helper'

class FluidpayTest < Test::Unit::TestCase
  def setup
    @gateway = FluidpayGateway.new(api_key: 'login')
    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'ch093mk6lr8qchacmbag', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response
  end

  def test_failed_authorize
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_capture
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    response = @gateway.capture(@amount, 'authorization id')
    assert_success response
  end

  def xtest_failed_capture
  end

  def test_successful_refund
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    response = @gateway.refund(@amount, 'authorization id')
    assert_success response
  end

  def xtest_failed_refund
  end

  def test_successful_void
    @gateway.expects(:ssl_request).returns(successful_void_response)

    response = @gateway.void('authorization id')
    assert_success response
  end

  def xtest_failed_void
  end

  def test_successful_verify
    @gateway.expects(:ssl_request).returns(successful_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response
  end

  def test_failed_verify
    @gateway.expects(:ssl_request).returns(failed_verify_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_email
    email = 'email@example.com'
    @options[:email] = email

    @gateway.expects(:ssl_request).with do |_http_method, _url, raw_request_body, _headers|
      request_body = JSON.parse(raw_request_body)
      assert_equal email, request_body['email_address']
      assert_equal email, request_body.dig('billing_address', 'email')
      true
    end.returns(successful_purchase_response)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_ip
    ip = '1.1.1.1'
    @options[:ip] = ip

    @gateway.expects(:ssl_request).with do |_http_method, _url, raw_request_body, _headers|
      request_body = JSON.parse(raw_request_body)
      assert_equal ip, request_body['ip_address']
      true
    end.returns(successful_purchase_response)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_first_last_name
    @gateway.expects(:ssl_request).with do |_http_method, _url, raw_request_body, _headers|
      request_body = JSON.parse(raw_request_body)
      assert_equal 'Longbob', request_body.dig('billing_address', 'first_name')
      assert_equal 'Longsen', request_body.dig('billing_address', 'last_name')
      true
    end.returns(successful_purchase_response)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_3ds
    @options[:three_d_secure] = {
      eci: 'eci',
      xid: 'xid',
      cavv: 'cavv',
      version: '2.0',
      ds_transaction_id: 'ds_transaction_id',
      acs_transaction_id: 'acs_transaction_id'
    }

    @gateway.expects(:ssl_request).with do |_http_method, _url, raw_request_body, _headers|
      request_body = JSON.parse(raw_request_body)
      assert_equal 'eci', request_body.dig('payment_method', 'card', 'cardholder_authentication', 'eci')
      assert_equal 'xid', request_body.dig('payment_method', 'card', 'cardholder_authentication', 'xid')
      assert_equal 'cavv', request_body.dig('payment_method', 'card', 'cardholder_authentication', 'cavv')
      assert_equal '2', request_body.dig('payment_method', 'card', 'cardholder_authentication', 'version')
      assert_equal 'ds_transaction_id', request_body.dig('payment_method', 'card', 'cardholder_authentication', 'ds_transaction_id')
      assert_equal 'acs_transaction_id', request_body.dig('payment_method', 'card', 'cardholder_authentication', 'acs_transaction_id')

      true
    end.returns(successful_purchase_response)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_billing_method
    @options[:billing_method] = 'recurring'

    @gateway.expects(:ssl_request).with do |_http_method, _url, raw_request_body, _headers|
      request_body = JSON.parse(raw_request_body)
      assert_equal 'recurring', request_body['billing_method']

      true
    end.returns(successful_purchase_response)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_descriptor
    @options[:descriptor] = {
      name: 'Descriptor Name',
      address: '123 Main St.',
      city: 'Boulder',
      state: 'CO',
      postal_code: '80302'
    }

    @gateway.expects(:ssl_request).with do |_http_method, _url, raw_request_body, _headers|
      request_body = JSON.parse(raw_request_body)
      assert_equal 'Descriptor Name', request_body.dig('descriptor', 'name')
      assert_equal '123 Main St.', request_body.dig('descriptor', 'address')
      assert_equal 'Boulder', request_body.dig('descriptor', 'city')
      assert_equal 'CO', request_body.dig('descriptor', 'state')
      assert_equal '80302', request_body.dig('descriptor', 'postal_code')


      true
    end.returns(successful_purchase_response)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_extra_fields_on_purchase
    @options[:card_on_file_indicator] = 'C'
    @options[:initiated_by] = 'merchant'
    @options[:initial_transaction_id] = 'abc123'
    @options[:stored_credential_indicator] = 'stored'

    @gateway.expects(:ssl_request).with do |_http_method, _url, raw_request_body, _headers|
      request_body = JSON.parse(raw_request_body)
      assert_equal 'C', request_body['card_on_file_indicator']
      assert_equal 'merchant', request_body['initiated_by']
      assert_equal 'abc123', request_body['initial_transaction_id']
      assert_equal 'stored', request_body['stored_credential_indicator']

      true
    end.returns(successful_purchase_response)

    @gateway.purchase(@amount, @credit_card, @options)
  end

  def test_extra_fields_on_authorize
    @options[:card_on_file_indicator] = 'C'
    @options[:initiated_by] = 'merchant'
    @options[:initial_transaction_id] = 'abc123'
    @options[:stored_credential_indicator] = 'stored'

    @gateway.expects(:ssl_request).with do |_http_method, _url, raw_request_body, _headers|
      request_body = JSON.parse(raw_request_body)
      assert_equal 'C', request_body['card_on_file_indicator']
      assert_equal 'merchant', request_body['initiated_by']
      assert_equal 'abc123', request_body['initial_transaction_id']
      assert_equal 'stored', request_body['stored_credential_indicator']

      true
    end.returns(successful_authorize_response)

    @gateway.authorize(@amount, @credit_card, @options)
  end

  def test_extra_fields_on_verify
    @options[:card_on_file_indicator] = 'C'
    @options[:initiated_by] = 'merchant'
    @options[:initial_transaction_id] = 'abc123'
    @options[:stored_credential_indicator] = 'stored'

    @gateway.expects(:ssl_request).with do |_http_method, _url, raw_request_body, _headers|
      request_body = JSON.parse(raw_request_body)
      assert_equal 'C', request_body['card_on_file_indicator']
      assert_equal 'merchant', request_body['initiated_by']
      assert_equal 'abc123', request_body['initial_transaction_id']
      assert_equal 'stored', request_body['stored_credential_indicator']

      true
    end.returns(successful_verify_response)

    @gateway.verify(@credit_card, @options)
  end

  def xtest_scrub
    assert @gateway.supports_scrubbing?
    assert_equal @gateway.scrub(pre_scrubbed), post_scrubbed
  end

  private

  def pre_scrubbed
    %q(
      Run the remote tests for this gateway, and then put the contents of transcript.log here.
    )
  end

  def post_scrubbed
    %q(
      Put the scrubbed contents of transcript.log here after implementing your scrubbing function.
      Things to scrub:
        - Credit card number
        - CVV
        - Sensitive authentication details
    )
  end

  def successful_purchase_response
    %(
      {"status":"success","msg":"success","data":{"id":"ch093mk6lr8qchacmbag","user_id":"cgvdncs6lr8qchace4b0","user_name":"inspirecommerce_test","merchant_id":"cgvdncs6lr8qchace4ag","merchant_name":"","idempotency_key":"","idempotency_time":0,"type":"sale","amount":100,"base_amount":100,"amount_authorized":100,"amount_captured":100,"amount_settled":0,"amount_refunded":0,"payment_adjustment":0,"tip_amount":0,"settlement_batch_id":"","processor_id":"cgvdnt46lr8qchace4o0","processor_type":"tsys_sierra","processor_name":"TSYS","payment_method":"card","payment_type":"card","features":["fake_response"],"national_tax_amount":0,"duty_amount":0,"ship_from_postal_code":"","summary_commodity_code":"","merchant_vat_registration_number":"","customer_vat_registration_number":"","tax_amount":0,"tax_exempt":false,"shipping_amount":0,"surcharge":0,"discount_amount":0,"service_fee":0,"currency":"usd","description":"Store Purchase","order_id":"168195324131","po_number":"","ip_address":"2601:280:5f00:4b0:1200:58c7:bf27:bc0f","transaction_source":"api","email_receipt":false,"email_address":"","customer_id":"","customer_payment_type":"","customer_payment_id":"","subscription_id":"","referenced_transaction_id":"","response_body":{"card":{"id":"ch093mk6lr8qchacmbb0","card_type":"visa","first_six":"411111","last_four":"1111","masked_card":"411111******1111","expiration_date":"09/24","response":"approved","response_code":100,"auth_code":"TAS000","processor_response_code":"00","processor_response_text":"APPROVAL TAS000 ","processor_transaction_id":"000000000000000","processor_type":"tsys_sierra","processor_id":"cgvdnt46lr8qchace4o0","bin_type":"","type":"credit","avs_response_code":"","cvv_response_code":"","processor_specific":"","created_at":"0001-01-01T00:00:00Z","updated_at":"0001-01-01T00:00:00Z"}},"custom_fields":{},"line_items":null,"status":"pending_settlement","response":"approved","response_code":100,"billing_address":{"first_name":"","last_name":"","company":"","address_line_1":"","address_line_2":"","city":"","state":"","postal_code":"","country":"","phone":"","fax":"","email":""},"shipping_address":{"first_name":"","last_name":"","company":"","address_line_1":"","address_line_2":"","city":"","state":"","postal_code":"","country":"","phone":"","fax":"","email":""},"created_at":"2023-04-20T01:14:02.933479454Z","updated_at":"2023-04-20T01:14:02.933479454Z","captured_at":"2023-04-20T01:14:02.946968838Z","settled_at":null}}
    )
  end

  def failed_purchase_response
    %(
      {"status":"success","msg":"success","data":{"id":"ch0a2ec6lr8qchacmbi0","user_id":"cgvdncs6lr8qchace4b0","user_name":"inspirecommerce_test","merchant_id":"cgvdncs6lr8qchace4ag","merchant_name":"","idempotency_key":"","idempotency_time":0,"type":"sale","amount":100,"base_amount":100,"amount_authorized":0,"amount_captured":0,"amount_settled":0,"amount_refunded":0,"payment_adjustment":0,"tip_amount":0,"settlement_batch_id":"","processor_id":"cgvdnt46lr8qchace4o0","processor_type":"tsys_sierra","processor_name":"TSYS","payment_method":"card","payment_type":"card","features":null,"national_tax_amount":0,"duty_amount":0,"ship_from_postal_code":"","summary_commodity_code":"","merchant_vat_registration_number":"","customer_vat_registration_number":"","tax_amount":0,"tax_exempt":false,"shipping_amount":0,"surcharge":0,"discount_amount":0,"service_fee":0,"currency":"usd","description":"Store Purchase","order_id":"168195717613","po_number":"","ip_address":"2601:280:5f00:4b0:2891:3e28:f92f:31fa","transaction_source":"api","email_receipt":false,"email_address":"","customer_id":"","customer_payment_type":"","customer_payment_id":"","subscription_id":"","referenced_transaction_id":"","response_body":{"card":{"id":"ch0a2ec6lr8qchacmbig","card_type":"visa","first_six":"400000","last_four":"0002","masked_card":"400000******0002","expiration_date":"09/24","response":"declined","response_code":334,"auth_code":"","processor_response_code":"","processor_response_text":"category_card_decline rule triggered","processor_transaction_id":"","processor_type":"tsys_sierra","processor_id":"cgvdnt46lr8qchace4o0","bin_type":"BUSINESS","type":"credit","avs_response_code":"","cvv_response_code":"","processor_specific":{"original_processor_response_code":"201"},"created_at":"0001-01-01T00:00:00Z","updated_at":"0001-01-01T00:00:00Z"}},"custom_fields":{},"line_items":null,"status":"declined","response":"declined","response_code":334,"billing_address":{"first_name":"","last_name":"","company":"","address_line_1":"","address_line_2":"","city":"","state":"","postal_code":"","country":"","phone":"","fax":"","email":""},"shipping_address":{"first_name":"","last_name":"","company":"","address_line_1":"","address_line_2":"","city":"","state":"","postal_code":"","country":"","phone":"","fax":"","email":""},"created_at":"2023-04-20T02:19:37.164544735Z","updated_at":"2023-04-20T02:19:37.164544735Z","captured_at":null,"settled_at":null}}
    )
  end

  def successful_authorize_response
    %(
      {"status":"success","msg":"success","data":{"id":"ch0a9o46lr8qchacmc0g","user_id":"cgvdncs6lr8qchace4b0","user_name":"inspirecommerce_test","merchant_id":"cgvdncs6lr8qchace4ag","merchant_name":"","idempotency_key":"","idempotency_time":0,"type":"authorize","amount":100,"base_amount":100,"amount_authorized":100,"amount_captured":0,"amount_settled":0,"amount_refunded":0,"payment_adjustment":0,"tip_amount":0,"settlement_batch_id":"","processor_id":"cgvdnt46lr8qchace4o0","processor_type":"tsys_sierra","processor_name":"TSYS","payment_method":"card","payment_type":"card","features":["fake_response"],"national_tax_amount":0,"duty_amount":0,"ship_from_postal_code":"","summary_commodity_code":"","merchant_vat_registration_number":"","customer_vat_registration_number":"","tax_amount":0,"tax_exempt":false,"shipping_amount":0,"surcharge":0,"discount_amount":0,"service_fee":0,"currency":"usd","description":"Store Purchase","order_id":"168195811191","po_number":"","ip_address":"2601:280:5f00:4b0:2891:3e28:f92f:31fa","transaction_source":"api","email_receipt":false,"email_address":"","customer_id":"","customer_payment_type":"","customer_payment_id":"","subscription_id":"","referenced_transaction_id":"","response_body":{"card":{"id":"ch0a9o46lr8qchacmc10","card_type":"visa","first_six":"411111","last_four":"1111","masked_card":"411111******1111","expiration_date":"09/24","response":"approved","response_code":100,"auth_code":"TAS000","processor_response_code":"00","processor_response_text":"APPROVAL TAS000 ","processor_transaction_id":"000000000000000","processor_type":"tsys_sierra","processor_id":"cgvdnt46lr8qchace4o0","bin_type":"","type":"credit","avs_response_code":"","cvv_response_code":"","processor_specific":"","created_at":"0001-01-01T00:00:00Z","updated_at":"0001-01-01T00:00:00Z"}},"custom_fields":{},"line_items":null,"status":"authorized","response":"approved","response_code":100,"billing_address":{"first_name":"","last_name":"","company":"","address_line_1":"","address_line_2":"","city":"","state":"","postal_code":"","country":"","phone":"","fax":"","email":""},"shipping_address":{"first_name":"","last_name":"","company":"","address_line_1":"","address_line_2":"","city":"","state":"","postal_code":"","country":"","phone":"","fax":"","email":""},"created_at":"2023-04-20T02:35:12.984484345Z","updated_at":"2023-04-20T02:35:12.984484345Z","captured_at":null,"settled_at":null}}
    )
  end

  def failed_authorize_response
    %(
      {"status":"success","msg":"success","data":{"id":"ch0aatk6lr8qchacmc30","user_id":"cgvdncs6lr8qchace4b0","user_name":"inspirecommerce_test","merchant_id":"cgvdncs6lr8qchace4ag","merchant_name":"","idempotency_key":"","idempotency_time":0,"type":"authorize","amount":100,"base_amount":100,"amount_authorized":0,"amount_captured":0,"amount_settled":0,"amount_refunded":0,"payment_adjustment":0,"tip_amount":0,"settlement_batch_id":"","processor_id":"cgvdnt46lr8qchace4o0","processor_type":"tsys_sierra","processor_name":"TSYS","payment_method":"card","payment_type":"card","features":null,"national_tax_amount":0,"duty_amount":0,"ship_from_postal_code":"","summary_commodity_code":"","merchant_vat_registration_number":"","customer_vat_registration_number":"","tax_amount":0,"tax_exempt":false,"shipping_amount":0,"surcharge":0,"discount_amount":0,"service_fee":0,"currency":"usd","description":"Store Purchase","order_id":"168195826177","po_number":"","ip_address":"2601:280:5f00:4b0:2891:3e28:f92f:31fa","transaction_source":"api","email_receipt":false,"email_address":"","customer_id":"","customer_payment_type":"","customer_payment_id":"","subscription_id":"","referenced_transaction_id":"","response_body":{"card":{"id":"ch0aatk6lr8qchacmc3g","card_type":"visa","first_six":"400000","last_four":"0002","masked_card":"400000******0002","expiration_date":"09/24","response":"declined","response_code":334,"auth_code":"","processor_response_code":"","processor_response_text":"category_card_decline rule triggered","processor_transaction_id":"","processor_type":"tsys_sierra","processor_id":"cgvdnt46lr8qchace4o0","bin_type":"BUSINESS","type":"credit","avs_response_code":"","cvv_response_code":"","processor_specific":{"original_processor_response_code":"201"},"created_at":"0001-01-01T00:00:00Z","updated_at":"0001-01-01T00:00:00Z"}},"custom_fields":{},"line_items":null,"status":"declined","response":"declined","response_code":334,"billing_address":{"first_name":"","last_name":"","company":"","address_line_1":"","address_line_2":"","city":"","state":"","postal_code":"","country":"","phone":"","fax":"","email":""},"shipping_address":{"first_name":"","last_name":"","company":"","address_line_1":"","address_line_2":"","city":"","state":"","postal_code":"","country":"","phone":"","fax":"","email":""},"created_at":"2023-04-20T02:37:42.748617048Z","updated_at":"2023-04-20T02:37:42.748617048Z","captured_at":null,"settled_at":null}}
    )
  end

  def successful_capture_response
    %(
      {"status":"success","msg":"success","data":{"id":"ch0abbk6lr8qchacmc5g","user_id":"cgvdncs6lr8qchace4b0","user_name":"inspirecommerce_test","merchant_id":"cgvdncs6lr8qchace4ag","merchant_name":"","idempotency_key":"","idempotency_time":0,"type":"authorize","amount":100,"base_amount":100,"amount_authorized":100,"amount_captured":100,"amount_settled":0,"amount_refunded":0,"payment_adjustment":0,"tip_amount":0,"settlement_batch_id":"","processor_id":"cgvdnt46lr8qchace4o0","processor_type":"tsys_sierra","processor_name":"TSYS","payment_method":"card","payment_type":"card","features":["fake_response"],"national_tax_amount":0,"duty_amount":0,"ship_from_postal_code":"","summary_commodity_code":"","merchant_vat_registration_number":"","customer_vat_registration_number":"","tax_amount":0,"tax_exempt":false,"shipping_amount":0,"surcharge":0,"discount_amount":0,"service_fee":0,"currency":"usd","description":"Store Purchase","order_id":"168195831708","po_number":"","ip_address":"2601:280:5f00:4b0:2891:3e28:f92f:31fa","transaction_source":"api","email_receipt":false,"email_address":"","customer_id":"","customer_payment_type":"","customer_payment_id":"","subscription_id":"","referenced_transaction_id":"","response_body":{"card":{"id":"ch0abbk6lr8qchacmc60","card_type":"visa","first_six":"411111","last_four":"1111","masked_card":"411111******1111","expiration_date":"09/24","response":"approved","response_code":100,"auth_code":"TAS000","processor_response_code":"00","processor_response_text":"APPROVAL TAS000 ","processor_transaction_id":"000000000000000","processor_type":"tsys_sierra","processor_id":"cgvdnt46lr8qchace4o0","bin_type":"","type":"credit","avs_response_code":"","cvv_response_code":"","processor_specific":"","created_at":"2023-04-20T02:38:38Z","updated_at":"2023-04-20T02:38:38Z"}},"custom_fields":{},"line_items":null,"status":"pending_settlement","response":"approved","response_code":100,"billing_address":{"first_name":"","last_name":"","company":"","address_line_1":"","address_line_2":"","city":"","state":"","postal_code":"","country":"","phone":"","fax":"","email":""},"shipping_address":{"first_name":"","last_name":"","company":"","address_line_1":"","address_line_2":"","city":"","state":"","postal_code":"","country":"","phone":"","fax":"","email":""},"created_at":"2023-04-20T02:38:38Z","updated_at":"2023-04-20T02:38:38.246637468Z","captured_at":"2023-04-20T02:38:38.246625979Z","settled_at":null}}
    )
  end

  def successful_refund_response
    %(
      {"status":"success","msg":"success","data":{"id":"ch0acl46lr8qchacmcb0","user_id":"cgvdncs6lr8qchace4b0","user_name":"inspirecommerce_test","merchant_id":"cgvdncs6lr8qchace4ag","merchant_name":"","idempotency_key":"","idempotency_time":0,"type":"refund","amount":100,"base_amount":100,"amount_authorized":100,"amount_captured":100,"amount_settled":0,"amount_refunded":0,"payment_adjustment":0,"tip_amount":0,"settlement_batch_id":"","processor_id":"cgvdnt46lr8qchace4o0","processor_type":"tsys_sierra","processor_name":"TSYS","payment_method":"card","payment_type":"card","features":["fake_response"],"national_tax_amount":0,"duty_amount":0,"ship_from_postal_code":"","summary_commodity_code":"","merchant_vat_registration_number":"","customer_vat_registration_number":"","tax_amount":0,"tax_exempt":false,"shipping_amount":0,"surcharge":0,"discount_amount":0,"service_fee":0,"currency":"usd","description":"","order_id":"168195848340","po_number":"","ip_address":"2601:280:5f00:4b0:2891:3e28:f92f:31fa","transaction_source":"api","email_receipt":false,"email_address":"","customer_id":"","customer_payment_type":"","customer_payment_id":"","subscription_id":"","referenced_transaction_id":"ch0acl46lr8qchacmc8g","response_body":{"card":{"id":"ch0acl46lr8qchacmcbg","card_type":"visa","first_six":"411111","last_four":"1111","masked_card":"411111******1111","expiration_date":"09/24","response":"approved","response_code":100,"auth_code":"TAS000","processor_response_code":"00","processor_response_text":"APPROVAL TAS000 ","processor_transaction_id":"000000000000000","processor_type":"tsys_sierra","processor_id":"cgvdnt46lr8qchace4o0","bin_type":"","type":"credit","avs_response_code":"","cvv_response_code":"","processor_specific":"","created_at":"0001-01-01T00:00:00Z","updated_at":"0001-01-01T00:00:00Z"}},"custom_fields":null,"line_items":null,"status":"pending_settlement","response":"approved","response_code":100,"billing_address":{"first_name":"","last_name":"","company":"","address_line_1":"","address_line_2":"","city":"","state":"","postal_code":"","country":"","phone":"","fax":"","email":""},"shipping_address":{"first_name":"","last_name":"","company":"","address_line_1":"","address_line_2":"","city":"","state":"","postal_code":"","country":"","phone":"","fax":"","email":""},"created_at":"2023-04-20T02:41:24.615516854Z","updated_at":"2023-04-20T02:41:24.615516854Z","captured_at":"2023-04-20T02:41:24.624174222Z","settled_at":null}}
    )
  end

  def successful_void_response
    %(
      {"status":"success","msg":"success","data":{"id":"ch0ae0c6lr8qchacmcd0","type":"void"}}
    )
  end

  def successful_verify_response
    %(
      {"status":"success","msg":"success","data":{"id":"ch0aef46lr8qchacmcg0","user_id":"cgvdncs6lr8qchace4b0","user_name":"inspirecommerce_test","merchant_id":"cgvdncs6lr8qchace4ag","merchant_name":"","idempotency_key":"","idempotency_time":0,"type":"verification","amount":100,"base_amount":100,"amount_authorized":0,"amount_captured":0,"amount_settled":0,"amount_refunded":0,"payment_adjustment":0,"tip_amount":0,"settlement_batch_id":"","processor_id":"cgvdnt46lr8qchace4o0","processor_type":"tsys_sierra","processor_name":"TSYS","payment_method":"card","payment_type":"card","features":["fake_response"],"national_tax_amount":0,"duty_amount":0,"ship_from_postal_code":"","summary_commodity_code":"","merchant_vat_registration_number":"","customer_vat_registration_number":"","tax_amount":0,"tax_exempt":false,"shipping_amount":0,"surcharge":0,"discount_amount":0,"service_fee":0,"currency":"usd","description":"Store Purchase","order_id":"168195871549","po_number":"","ip_address":"2601:280:5f00:4b0:2891:3e28:f92f:31fa","transaction_source":"api","email_receipt":false,"email_address":"","customer_id":"","customer_payment_type":"","customer_payment_id":"","subscription_id":"","referenced_transaction_id":"","response_body":{"card":{"id":"ch0aef46lr8qchacmcgg","card_type":"visa","first_six":"411111","last_four":"1111","masked_card":"411111******1111","expiration_date":"09/24","response":"approved","response_code":100,"auth_code":"TAS000","processor_response_code":"00","processor_response_text":"APPROVAL TAS000 ","processor_transaction_id":"000000000000000","processor_type":"tsys_sierra","processor_id":"cgvdnt46lr8qchace4o0","bin_type":"","type":"credit","avs_response_code":"","cvv_response_code":"","processor_specific":"","created_at":"0001-01-01T00:00:00Z","updated_at":"0001-01-01T00:00:00Z"}},"custom_fields":{},"line_items":null,"status":"authorized","response":"approved","response_code":100,"billing_address":{"first_name":"","last_name":"","company":"","address_line_1":"","address_line_2":"","city":"","state":"","postal_code":"","country":"","phone":"","fax":"","email":""},"shipping_address":{"first_name":"","last_name":"","company":"","address_line_1":"","address_line_2":"","city":"","state":"","postal_code":"","country":"","phone":"","fax":"","email":""},"created_at":"2023-04-20T02:45:16.457889609Z","updated_at":"2023-04-20T02:45:16.457889609Z","captured_at":null,"settled_at":null}}
    )
  end

  def failed_verify_response
    %(
      {"status":"success","msg":"success","data":{"id":"ch0afm46lr8qchacmcig","user_id":"cgvdncs6lr8qchace4b0","user_name":"inspirecommerce_test","merchant_id":"cgvdncs6lr8qchace4ag","merchant_name":"","idempotency_key":"","idempotency_time":0,"type":"verification","amount":100,"base_amount":100,"amount_authorized":0,"amount_captured":0,"amount_settled":0,"amount_refunded":0,"payment_adjustment":0,"tip_amount":0,"settlement_batch_id":"","processor_id":"cgvdnt46lr8qchace4o0","processor_type":"tsys_sierra","processor_name":"TSYS","payment_method":"card","payment_type":"card","features":null,"national_tax_amount":0,"duty_amount":0,"ship_from_postal_code":"","summary_commodity_code":"","merchant_vat_registration_number":"","customer_vat_registration_number":"","tax_amount":0,"tax_exempt":false,"shipping_amount":0,"surcharge":0,"discount_amount":0,"service_fee":0,"currency":"usd","description":"Store Purchase","order_id":"168195887099","po_number":"","ip_address":"2601:280:5f00:4b0:2891:3e28:f92f:31fa","transaction_source":"api","email_receipt":false,"email_address":"","customer_id":"","customer_payment_type":"","customer_payment_id":"","subscription_id":"","referenced_transaction_id":"","response_body":{"card":{"id":"ch0afm46lr8qchacmcj0","card_type":"visa","first_six":"400000","last_four":"0002","masked_card":"400000******0002","expiration_date":"09/24","response":"declined","response_code":334,"auth_code":"","processor_response_code":"","processor_response_text":"category_card_decline rule triggered","processor_transaction_id":"","processor_type":"tsys_sierra","processor_id":"cgvdnt46lr8qchace4o0","bin_type":"BUSINESS","type":"credit","avs_response_code":"","cvv_response_code":"","processor_specific":{"original_processor_response_code":"201"},"created_at":"0001-01-01T00:00:00Z","updated_at":"0001-01-01T00:00:00Z"}},"custom_fields":{},"line_items":null,"status":"declined","response":"declined","response_code":334,"billing_address":{"first_name":"","last_name":"","company":"","address_line_1":"","address_line_2":"","city":"","state":"","postal_code":"","country":"","phone":"","fax":"","email":""},"shipping_address":{"first_name":"","last_name":"","company":"","address_line_1":"","address_line_2":"","city":"","state":"","postal_code":"","country":"","phone":"","fax":"","email":""},"created_at":"2023-04-20T02:47:52.053916844Z","updated_at":"2023-04-20T02:47:52.053916844Z","captured_at":null,"settled_at":null}}
    )
  end
end
