require 'test_helper'

class RemoteFluidpayTest < Test::Unit::TestCase
  def setup
    @gateway = FluidpayGateway.new(fixtures(:fluidpay))

    @amount = 100
    @credit_card = credit_card('4111111111111111')
    @declined_card = credit_card('4000000000000002')
    @options = {
      order_id: generate_order_id,
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'approved', response.message
  end

  def test_successful_purchase_with_more_options
    order_id = generate_order_id
    ip = "127.0.0.3"
    email = "joe@example.com"

    options = {
      order_id: order_id,
      ip: ip,
      email: email
    }

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'approved', response.message
    assert_equal order_id, response.params.dig('data', 'order_id')
    assert_equal ip, response.params.dig('data', 'ip_address')
    assert_equal email, response.params.dig('data', 'email_address')
    assert_equal email, response.params.dig('data', 'billing_address', 'email')
  end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'declined', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'approved', capture.message
  end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'declined', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert capture = @gateway.capture(@amount-1, auth.authorization)
    assert_success capture
  end

  def xtest_failed_capture
    response = @gateway.capture(@amount, '')
    assert_failure response
    assert_equal 'REPLACE WITH FAILED CAPTURE MESSAGE', response.message
  end

  def test_successful_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization)
    assert_success refund
    assert_equal 'approved', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization)
    assert_success refund
  end

  def xtest_failed_refund
    response = @gateway.refund(@amount, '')
    assert_failure response
    assert_equal 'REPLACE WITH FAILED REFUND MESSAGE', response.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'void', void.message
  end

  def xtest_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'REPLACE WITH FAILED VOID MESSAGE', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match 'approved', response.message
  end

  def test_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match 'declined', response.message
  end

  def xtest_invalid_login
    gateway = FluidpayGateway.new(login: '', password: '')

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match %r{REPLACE WITH FAILED LOGIN MESSAGE}, response.message
  end

  def xtest_dump_transcript
    # This test will run a purchase transaction on your gateway
    # and dump a transcript of the HTTP conversation so that
    # you can use that transcript as a reference while
    # implementing your scrubbing logic.  You can delete
    # this helper after completing your scrub implementation.
    dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  end

  def xtest_transcript_scrubbing
    transcript = capture_transcript(@gateway) do
      @gateway.purchase(@amount, @credit_card, @options)
    end
    transcript = @gateway.scrub(transcript)

    assert_scrubbed(@credit_card.number, transcript)
    assert_scrubbed(@credit_card.verification_value, transcript)
    assert_scrubbed(@gateway.options[:password], transcript)
  end

  def generate_order_id
    (Time.now.to_f * 100).to_i.to_s
  end
end
