require 'test_helper'

class RemoteWorldNetV2Test < Test::Unit::TestCase
  def setup
    @gateway = WorldNetV2Gateway.new(fixtures(:world_net_v2))

    @amount = 100
    @credit_card = credit_card('4539858876047062')
    @declined_card = @credit_card
    @options = {
      order_id: generate_order_id,
      billing_address: address,
    }
  end

  def test_successful_purchase
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'COMPLETE', response.message
  end

  def test_successful_purchase_with_more_options
    options = @options.merge({
      ip: "127.0.0.1",
      email: "joe@example.com",
      description: "Transaction description"
    })

    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal 'COMPLETE', response.message
  end

  def test_failed_purchase
    @amount = 101
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'DECLINED', response.message
  end

  def test_successful_authorize_and_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'PENDING', auth.message

    assert capture = @gateway.capture(@amount, auth.authorization)
    assert_success capture
    assert_equal 'READY', capture.message
  end

  def test_failed_authorize
    @amount = 101
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'DECLINED', response.message
  end

  def test_partial_capture
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth
    assert_equal 'PENDING', auth.message

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

    assert refund = @gateway.refund(@amount, purchase.authorization, { reason: 'Refund reason' })
    assert_success refund
    assert_equal 'VOID', refund.message
  end

  def test_partial_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount-1, purchase.authorization, { reason: 'Partial refund reason' })
    assert_success refund
    assert_equal 'READY', refund.message
  end

  def xtest_failed_refund
    purchase = @gateway.purchase(@amount, @credit_card, @options)
    assert_success purchase

    assert refund = @gateway.refund(@amount, purchase.authorization, { reason: 'Failed refund reason' })
    assert_failure refund
    assert_equal 'fdjdsafkdsajf', refund.message
  end

  def test_successful_void
    auth = @gateway.authorize(@amount, @credit_card, @options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
    assert_equal 'VOID', void.message
  end

  def xtest_failed_void
    response = @gateway.void('')
    assert_failure response
    assert_equal 'REPLACE WITH FAILED VOID MESSAGE', response.message
  end

  def test_successful_verify
    response = @gateway.verify(@credit_card, @options)
    assert_success response
    assert_match 'PENDING', response.message
  end

  def xtest_failed_verify
    response = @gateway.verify(@declined_card, @options)
    assert_failure response
    assert_match %r{REPLACE WITH FAILED PURCHASE MESSAGE}, response.message
  end

  def xtest_invalid_login
    gateway = WorldNetV2Gateway.new(login: '', password: '')

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
    assert_scrubbed(@gateway.token[:token], transcript)
  end

  def generate_order_id
    (Time.now.to_f * 100).to_i.to_s
  end
end
