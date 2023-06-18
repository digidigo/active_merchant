require 'test_helper'
require 'securerandom'

require 'irb'

class RemotePathlyTest < Test::Unit::TestCase
  def setup
    @gateway = PathlyGateway.new(fixtures(:pathly))

    @amount = 100
    
    @good_card = credit_card('5488888888888888')
    @bad_card = credit_card('5413131313131313')
    @three_ds_card = credit_card('9000100811111111')
    
    
    @options = {
      billing_address: address,
    }

    @good_card_id = SecureRandom.uuid
    @bad_card_id = SecureRandom.uuid
    @three_ds_card_id = SecureRandom.uuid

    @customer_data = {
      customer_id: SecureRandom.uuid,
      first_name: 'Peter',
      last_name: 'Griffin',
      email: 'peter@pathly.io',
      dob: {
        day: 9,
        month: 11,
        year: 1989
      },
      ssn: '123-456789',
      phone_number: '1234567890',
      address: {
        country: 'US',
        line1: 'Passatge sant pere',
        line2: 'Apartment 2',
        zip: '8397.0',
        city: 'Pineda de mar',
        state: 'Barcelona'
      },
      shipping: {
        name: 'Louis Griffin',
        phone_number: 'string',
        address: {
          country: 'US',
          line1: 'Passatge sant pere',
          line2: 'Apartment 2',
          zip: '8397.0',
          city: 'Pineda de mar',
          state: 'Barcelona'
        }
      }
    }

    response = @gateway.create_customer(@good_card,@customer_data)

    response = @gateway.create_card(@good_card, @options.merge({id: @good_card_id,customer_id: @customer_data[:customer_id] }))
    response = @gateway.create_card(@bad_card, @options.merge({id: @bad_card_id,customer_id: @customer_data[:customer_id] }))
    response = @gateway.create_card(@three_ds_card, @options.merge({id: @three_ds_card_id,customer_id: @customer_data[:customer_id] }))

    @failed_customer_data = @customer_data.merge({ customer_id: 'invalid'})
  end

  def test_successful_token_fetch
    token_options = fixtures(:pathly)
    token = ActiveMerchant::Billing::Pathly::Token.new(token_options)

    fetched_token = token.fetch

    assert_not_nil fetched_token
    assert fetched_token[:token].length > 0
    assert fetched_token[:expires_at] > Time.now
  end

 def test_create_card
    response = @gateway.create_card(@good_card, @options.merge({customer_id: @customer_data[:customer_id] }))
    assert_success response, "Expected success but got: #{response.inspect}"
  end

  def test_create_card_no_id
    response = @gateway.create_card(@good_card, @options.merge({ customer_id: @customer_data[:customer_id] }))
    assert_success response, "Expected success but got: #{response.inspect}"
  end

  def test_invalid_create_card
    card_id = SecureRandom.uuid
    response = @gateway.create_card(@good_card, @options.merge({ customer_id: @customer_data[:customer_id] }))
    assert_success response, "Expected success but got: #{response.inspect}"
  end

  def test_create_customer
    customer_data = @customer_data.merge({ customer_id: SecureRandom.uuid })
    response = @gateway.create_customer(@good_card,customer_data)
    assert_success response, "Expected success but got: #{response.inspect}"
  end
  
  def test_failed_create_customer
    response = @gateway.create_customer(@good_card,@failed_customer_data)
    assert_failure response, "Expected failure but got: #{response.inspect}"
    assert_equal 'id: Value \'invalid\' does not match format uuid of type string', response.message
    assert_match /.*id.*invalid.*uuid.*/ , response.message
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @good_card, @options.merge({  payment_method_id: @good_card_id, customer_id: @customer_data[:customer_id] }))
    assert_success response
    assert_match /Success.*/, response.message
  end

  def test_refund
    charge_id = SecureRandom.uuid

    response = @gateway.purchase(@amount, @good_card, @options.merge({ id: charge_id, payment_method_id: @good_card_id, customer_id: @customer_data[:customer_id] }))
    assert_success response
    assert_match /Success.*/, response.message

    auth_id = SecureRandom.uuid
    response = @gateway.refund(@amount, auth_id, { charge_id: charge_id, reason: 'duplicate' })
    assert_success response
    assert_match /Success.*/, response.message

  end

  def test_fail_refund
    charge_id = SecureRandom.uuid

    auth_id = SecureRandom.uuid
    response = @gateway.refund(@amount, auth_id, { charge_id: charge_id, reason: 'duplicate' })
    assert_failure response, "Expected failure but got: #{response.inspect}"
    assert_match /.*#{charge_id}.*/, response.message
  end

    def test_void
    charge_id = SecureRandom.uuid

    response = @gateway.purchase(@amount, @good_card, @options.merge({ id: charge_id, payment_method_id: @good_card_id, customer_id: @customer_data[:customer_id] }))
    assert_success response
    assert_match /Success.*/, response.message

    auth_id = SecureRandom.uuid
    response = @gateway.void(auth_id, { charge_id: charge_id, reason: 'duplicate' })
    assert_success response
    assert_match /Success.*/, response.message

  end

  def test_no_shipping_purchase
    response = @gateway.purchase(@amount, @good_card,{  payment_method_id: @good_card_id, customer_id: @customer_data[:customer_id] })
    assert_success response
    assert_match /Success.*/, response.message
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @bad_card, @options.merge({  payment_method_id: @bad_card_id, customer_id: @customer_data[:customer_id] }))
    assert_failure response, "Expected failure but got: #{response.inspect}"
    assert_match /.*PAN.*fail.*/, response.message
  end

  def test_three_ds_purchase
    response = @gateway.purchase(@amount, @three_ds_card, @options.merge({  payment_method_id: @three_ds_card_id, customer_id: @customer_data[:customer_id] }))
    assert_success response, "3DS purchase failed: #{response.inspect}"
    assert_equal '3DS Required', response.message
    assert_match /pathly/, response.params['data']['acs_url']
    assert_match /pathly/, response.params['redirect_url']
    assert response.params['redirect_required'], 'Redirect required not found'
  end

  def test_support_cv2_and_dynamic_descriptor
    options = @options.merge({  payment_method_id: @good_card_id, customer_id: @customer_data[:customer_id] })
    options.merge!({ cv2: '123', dynamic_descriptor: 'Acme Co Inc.' })
    response = @gateway.purchase(@amount, @good_card, options)
    assert_success response, "cv2 request success: #{response.inspect}"
    assert_match /Success.*/, response.message
  end

  def test_fail_support_cv2_and_dynamic_descriptor
    options = @options.merge({  payment_method_id: @good_card_id, customer_id: @customer_data[:customer_id] })
    options.merge!({ cv2: 'ABCDEF', dynamic_descriptor: 'Acme Co Inc.' })
    response = @gateway.purchase(@amount, @good_card, options)
    assert_failure response, "Expected failure but got: #{response.inspect}"
    assert_match /Length.*/, response.message
  end


 def build_card_data(card_type)
    card = case card_type
    when 'bad_card'
      {
        "id": @bad_card_id,
        "customer_id": @customer_id,
        "number": "5413131313131313", # example bad card number
        "exp_month": "12",
        "exp_year": "2025",
        "cvv": "123"
      }
    when 'good_card'
      {
        "id": @good_card_id,
        "customer_id": @customer_id,
        "number": "5488888888888888", # example good card number
         "exp_month": "12",
        "exp_year": "2025",
        "cvv": "123"
      }
    when 'three_ds_card'
      {
        "id": @three_ds_card_id,
        "customer_id": @customer_id,
        "number": "9000100811111111", # example 3DS card number
        "exp_month": "12",
        "exp_year": "2025",
        "cvv": "123"
      }
    end

    card["billing_details"] =   {
      "name": "Louis Griffin",
      "email": "foo@bar.com",
      "phone_number": "3036187555",
      "address": {
        "country": "US",
        "line1": "Passatge sant pere",
        "line2": "Apartment 2",
        "zip": "8397.0",
        "city": "Pineda de mar",
        "state": "Barcelona"
      }
    }

    card
  end



end
