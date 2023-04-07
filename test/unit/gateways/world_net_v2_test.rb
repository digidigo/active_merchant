require 'test_helper'

class WorldNetV2Test < Test::Unit::TestCase
  def setup
    @gateway = WorldNetV2Gateway.new(merchant_api_key: 'test')
    @token_mock = @gateway.expects(:token)

    @credit_card = credit_card
    @amount = 100

    @options = {
      order_id: '1',
      billing_address: address,
      description: 'Store Purchase'
    }
  end

  def test_successful_purchase
    @token_mock.twice.returns({ terminal: '123', token: 'token' })
    @gateway.expects(:ssl_request).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'I3ILXYOMWA', response.authorization
    assert response.test?
  end

  def test_failed_purchase
    @token_mock.twice.returns({ terminal: '123', token: 'token' })
    @gateway.expects(:ssl_request).returns(failed_purchase_response)

    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_authorize
    @token_mock.twice.returns({ terminal: '123', token: 'token' })
    @gateway.expects(:ssl_request).returns(successful_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_success response

    assert_equal 'FN1IBUZXMV', response.authorization
    assert response.test?
  end

  def test_failed_authorize
    @token_mock.twice.returns({ terminal: '123', token: 'token' })
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.authorize(@amount, @credit_card, @options)
    assert_failure response
    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
  end

  def test_successful_capture
    @token_mock.returns({ terminal: '123', token: 'token' })
    @gateway.expects(:ssl_request).returns(successful_capture_response)

    response = @gateway.capture(@amount, 'prior_authorization')
    assert_success response

    assert_equal 'L5T7R0NPZ4', response.authorization
    assert response.test?
  end

  def xtest_failed_capture
  end

  def test_successful_refund
    @token_mock.returns({ terminal: '123', token: 'token' })
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    options = @options.merge({ reason: 'Refund reason' })
    response = @gateway.refund(@amount, 'prior_authorization', options)
    assert_success response

    assert_equal 'KUWGNJIJ0O', response.authorization
    assert response.test?
  end

  def test_successful_refund_without_reason
    @token_mock.returns({ terminal: '123', token: 'token' })
    @gateway.expects(:ssl_request).returns(successful_refund_response)

    response = @gateway.refund(@amount, 'prior_authorization', @options)
    assert_success response

    assert_equal 'KUWGNJIJ0O', response.authorization
    assert response.test?
  end

  def xtest_failed_refund
  end

  def test_successful_void
    @token_mock.returns({ terminal: '123', token: 'token' })
    @gateway.expects(:ssl_request).returns(successful_void_response)

    response = @gateway.void('prior_authorization', @options)
    assert_success response

    assert_equal 'FLHDW7NR0J', response.authorization
    assert response.test?
  end

  def xtest_failed_void
  end

  def test_successful_verify
    @token_mock.times(3).returns({ terminal: '123', token: 'token' })
    @gateway.expects(:ssl_request).twice.returns(successful_authorize_response, successful_void_response)

    response = @gateway.verify(@credit_card, @options)
    assert_success response

    assert_equal 'FN1IBUZXMV', response.authorization
    assert response.test?
  end

  def xtest_successful_verify_with_failed_void
  end

  def test_failed_verify
    @token_mock.twice.returns({ terminal: '123', token: 'token' })
    @gateway.expects(:ssl_request).returns(failed_authorize_response)

    response = @gateway.verify(@credit_card, @options)
    assert_failure response

    assert_equal Gateway::STANDARD_ERROR_CODE[:card_declined], response.error_code
    assert response.test?
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
      {"uniqueReference":"I3ILXYOMWA","terminal":"5304001","order":{"orderId":"168082676785","currency":"USD","totalAmount":1.00},"customerAccount":{"cardType":"Visa Credit","cardholderName":"Longbob Longsen","maskedPan":"453985******7062","expiryDate":"0924","entryMethod":"KEYED"},"securityCheck":{"cvvResult":"M","avsResult":"Y"},"transactionResult":{"type":"SALE","status":"COMPLETE","approvalCode":"OK2115","dateTime":"2023-04-06T18:19:28.438-06:00","currency":"USD","authorizedAmount":1.00,"resultCode":"A","resultMessage":"OK2115"},"additionalDataFields":[{"name":"ORDER_NUM","value":"04012577"}],"receipts":[{"copy":"CARDHOLDER_COPY","header":"CARDHOLDER COPY","merchantDetails":[{"order":0,"label":"Company","value":"Thrifty Consulting"},{"order":1,"label":"Address","value":"Test, Test, United States"},{"order":2,"label":"Phone","value":"1234567890"}],"transactionData":[{"order":0,"label":"Cardholder Name","value":"Longbob Longsen"},{"order":1,"label":"Card acceptor number","value":"***********6138"},{"order":2,"label":"Terminal ID","value":"****0001"},{"order":3,"label":"Date/Time","value":"Apr 6, 2023 6:19:28 PM"},{"order":4,"label":"Transaction Data Source","value":"KEYED"},{"order":5,"label":"Transaction","value":"Purchase"},{"order":6,"label":"Type","value":"Customer Not Present"},{"order":7,"label":"Status","value":"COMPLETE"},{"order":8,"label":"Card","value":"453985******7062 09/24 (Visa Credit)"},{"order":9,"label":"Auth Response","value":"OK2115"},{"order":10,"label":"Authorisation Code","value":"OK2115"},{"order":11,"label":"Total Amount","value":"USD 1.00"}],"customFields":[],"iccData":[],"footer":"PLEASE RETAIN FOR YOUR RECORDS"},{"copy":"CARD_ACCEPTOR_COPY","header":"MERCHANT COPY","merchantDetails":[{"order":0,"label":"Company","value":"Thrifty Consulting"},{"order":1,"label":"Address","value":"Test, Test, United States"},{"order":2,"label":"Phone","value":"1234567890"}],"transactionData":[{"order":0,"label":"Cardholder Name","value":"Longbob Longsen"},{"order":1,"label":"Card acceptor number","value":"RCTST0000006138"},{"order":2,"label":"Terminal ID","value":"00000001"},{"order":3,"label":"Order ID","value":"168082676785"},{"order":4,"label":"Unique Ref","value":"I3ILXYOMWA"},{"order":5,"label":"Date/Time","value":"Apr 6, 2023 6:19:28 PM"},{"order":6,"label":"Transaction Data Source","value":"KEYED"},{"order":7,"label":"Transaction","value":"Purchase"},{"order":8,"label":"Type","value":"Customer Not Present"},{"order":9,"label":"Status","value":"COMPLETE"},{"order":10,"label":"Card","value":"453985******7062 09/24 (Visa Credit)"},{"order":11,"label":"Auth Response","value":"OK2115"},{"order":12,"label":"Authorisation Code","value":"OK2115"},{"order":13,"label":"Total Amount","value":"USD 1.00"}],"customFields":[],"iccData":[],"footer":"PLEASE DEBIT MY ACCOUNT WITH TOTAL SHOWN"}],"links":[{"rel":"refund","method":"POST","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/I3ILXYOMWA/refunds"},{"rel":"update","method":"PATCH","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/I3ILXYOMWA"},{"rel":"capture","method":"PATCH","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/I3ILXYOMWA/capture"},{"rel":"self","method":"GET","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/I3ILXYOMWA"},{"rel":"reverse","method":"PATCH","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/I3ILXYOMWA/reverse"}]}
    )
  end

  def failed_purchase_response
    %(
      {"uniqueReference":"CPTCWOZICK","terminal":"5304001","order":{"orderId":"168082704969","currency":"USD","totalAmount":1.01},"customerAccount":{"cardType":"Visa Credit","cardholderName":"Longbob Longsen","maskedPan":"453985******7062","expiryDate":"0924","entryMethod":"KEYED"},"securityCheck":{"cvvResult":"M","avsResult":"Y"},"transactionResult":{"type":"SALE","status":"DECLINED","approvalCode":"OK2116","dateTime":"2023-04-06T18:24:10.332-06:00","currency":"USD","authorizedAmount":1.01,"resultCode":"D","resultMessage":"Decline"},"additionalDataFields":[{"name":"ORDER_NUM","value":"04012601"}],"receipts":[{"copy":"CARDHOLDER_COPY","header":"CARDHOLDER COPY","merchantDetails":[{"order":0,"label":"Company","value":"Thrifty Consulting"},{"order":1,"label":"Address","value":"Test, Test, United States"},{"order":2,"label":"Phone","value":"1234567890"}],"transactionData":[{"order":0,"label":"Cardholder Name","value":"Longbob Longsen"},{"order":1,"label":"Card acceptor number","value":"***********6138"},{"order":2,"label":"Terminal ID","value":"****0001"},{"order":3,"label":"Date/Time","value":"Apr 6, 2023 6:24:10 PM"},{"order":4,"label":"Transaction Data Source","value":"KEYED"},{"order":5,"label":"Transaction","value":"Purchase"},{"order":6,"label":"Type","value":"Customer Not Present"},{"order":7,"label":"Status","value":"DECLINED"},{"order":8,"label":"Card","value":"453985******7062 09/24 (Visa Credit)"},{"order":9,"label":"Auth Response","value":"Decline"},{"order":10,"label":"Authorisation Code","value":"OK2116"},{"order":11,"label":"Total Amount","value":"USD 1.01"}],"customFields":[],"iccData":[],"footer":"PLEASE RETAIN FOR YOUR RECORDS"},{"copy":"CARD_ACCEPTOR_COPY","header":"MERCHANT COPY","merchantDetails":[{"order":0,"label":"Company","value":"Thrifty Consulting"},{"order":1,"label":"Address","value":"Test, Test, United States"},{"order":2,"label":"Phone","value":"1234567890"}],"transactionData":[{"order":0,"label":"Cardholder Name","value":"Longbob Longsen"},{"order":1,"label":"Card acceptor number","value":"RCTST0000006138"},{"order":2,"label":"Terminal ID","value":"00000001"},{"order":3,"label":"Order ID","value":"168082704969"},{"order":4,"label":"Unique Ref","value":"CPTCWOZICK"},{"order":5,"label":"Date/Time","value":"Apr 6, 2023 6:24:10 PM"},{"order":6,"label":"Transaction Data Source","value":"KEYED"},{"order":7,"label":"Transaction","value":"Purchase"},{"order":8,"label":"Type","value":"Customer Not Present"},{"order":9,"label":"Status","value":"DECLINED"},{"order":10,"label":"Card","value":"453985******7062 09/24 (Visa Credit)"},{"order":11,"label":"Auth Response","value":"Decline"},{"order":12,"label":"Authorisation Code","value":"OK2116"},{"order":13,"label":"Total Amount","value":"USD 1.01"}],"customFields":[],"iccData":[],"footer":"I WILL NOT BE CHARGED FOR THIS TRANSACTION"}],"links":[{"rel":"refund","method":"POST","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/CPTCWOZICK/refunds"},{"rel":"update","method":"PATCH","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/CPTCWOZICK"},{"rel":"capture","method":"PATCH","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/CPTCWOZICK/capture"},{"rel":"self","method":"GET","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/CPTCWOZICK"},{"rel":"reverse","method":"PATCH","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/CPTCWOZICK/reverse"}]}
    )
  end

  def successful_authorize_response
    %(
      {"uniqueReference":"FN1IBUZXMV","terminal":"5304001","order":{"orderId":"168088608414","currency":"USD","totalAmount":1.00},"customerAccount":{"cardType":"Visa Credit","cardholderName":"Longbob Longsen","maskedPan":"453985******7062","expiryDate":"0924","entryMethod":"KEYED"},"securityCheck":{"cvvResult":"M","avsResult":"Y"},"transactionResult":{"type":"SALE","status":"PENDING","approvalCode":"OK2525","dateTime":"2023-04-07T10:48:04.466-06:00","currency":"USD","authorizedAmount":1.00,"resultCode":"A","resultMessage":"OK2525"},"additionalDataFields":[{"name":"ORDER_NUM","value":"04012879"}],"receipts":[{"copy":"CARDHOLDER_COPY","header":"CARDHOLDER COPY","merchantDetails":[{"order":0,"label":"Company","value":"Thrifty Consulting"},{"order":1,"label":"Address","value":"Test, Test, United States"},{"order":2,"label":"Phone","value":"1234567890"}],"transactionData":[{"order":0,"label":"Cardholder Name","value":"Longbob Longsen"},{"order":1,"label":"Card acceptor number","value":"***********6138"},{"order":2,"label":"Terminal ID","value":"****0001"},{"order":3,"label":"Date/Time","value":"Apr 7, 2023 10:48:04 AM"},{"order":4,"label":"Transaction Data Source","value":"KEYED"},{"order":5,"label":"Transaction","value":"Purchase"},{"order":6,"label":"Type","value":"Customer Not Present"},{"order":7,"label":"Status","value":"PENDING"},{"order":8,"label":"Card","value":"453985******7062 09/24 (Visa Credit)"},{"order":9,"label":"Auth Response","value":"OK2525"},{"order":10,"label":"Authorisation Code","value":"OK2525"},{"order":11,"label":"Total Amount","value":"USD 1.00"}],"customFields":[],"iccData":[],"footer":"PLEASE RETAIN FOR YOUR RECORDS"},{"copy":"CARD_ACCEPTOR_COPY","header":"MERCHANT COPY","merchantDetails":[{"order":0,"label":"Company","value":"Thrifty Consulting"},{"order":1,"label":"Address","value":"Test, Test, United States"},{"order":2,"label":"Phone","value":"1234567890"}],"transactionData":[{"order":0,"label":"Cardholder Name","value":"Longbob Longsen"},{"order":1,"label":"Card acceptor number","value":"RCTST0000006138"},{"order":2,"label":"Terminal ID","value":"00000001"},{"order":3,"label":"Order ID","value":"168088608414"},{"order":4,"label":"Unique Ref","value":"FN1IBUZXMV"},{"order":5,"label":"Date/Time","value":"Apr 7, 2023 10:48:04 AM"},{"order":6,"label":"Transaction Data Source","value":"KEYED"},{"order":7,"label":"Transaction","value":"Purchase"},{"order":8,"label":"Type","value":"Customer Not Present"},{"order":9,"label":"Status","value":"PENDING"},{"order":10,"label":"Card","value":"453985******7062 09/24 (Visa Credit)"},{"order":11,"label":"Auth Response","value":"OK2525"},{"order":12,"label":"Authorisation Code","value":"OK2525"},{"order":13,"label":"Total Amount","value":"USD 1.00"}],"customFields":[],"iccData":[],"footer":"PLEASE DEBIT MY ACCOUNT WITH TOTAL SHOWN"}],"links":[{"rel":"refund","method":"POST","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/FN1IBUZXMV/refunds"},{"rel":"update","method":"PATCH","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/FN1IBUZXMV"},{"rel":"capture","method":"PATCH","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/FN1IBUZXMV/capture"},{"rel":"self","method":"GET","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/FN1IBUZXMV"},{"rel":"reverse","method":"PATCH","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/FN1IBUZXMV/reverse"}]}
    )
  end

  def failed_authorize_response
    %(
      {"uniqueReference":"IEFD1FTTUP","terminal":"5304001","order":{"orderId":"168088616547","currency":"USD","totalAmount":1.01},"customerAccount":{"cardType":"Visa Credit","cardholderName":"Longbob Longsen","maskedPan":"453985******7062","expiryDate":"0924","entryMethod":"KEYED"},"securityCheck":{"cvvResult":"M","avsResult":"Y"},"transactionResult":{"type":"SALE","status":"DECLINED","approvalCode":"OK2526","dateTime":"2023-04-07T10:49:25.804-06:00","currency":"USD","authorizedAmount":1.01,"resultCode":"D","resultMessage":"Decline"},"additionalDataFields":[{"name":"ORDER_NUM","value":"04012880"}],"receipts":[{"copy":"CARDHOLDER_COPY","header":"CARDHOLDER COPY","merchantDetails":[{"order":0,"label":"Company","value":"Thrifty Consulting"},{"order":1,"label":"Address","value":"Test, Test, United States"},{"order":2,"label":"Phone","value":"1234567890"}],"transactionData":[{"order":0,"label":"Cardholder Name","value":"Longbob Longsen"},{"order":1,"label":"Card acceptor number","value":"***********6138"},{"order":2,"label":"Terminal ID","value":"****0001"},{"order":3,"label":"Date/Time","value":"Apr 7, 2023 10:49:25 AM"},{"order":4,"label":"Transaction Data Source","value":"KEYED"},{"order":5,"label":"Transaction","value":"Purchase"},{"order":6,"label":"Type","value":"Customer Not Present"},{"order":7,"label":"Status","value":"DECLINED"},{"order":8,"label":"Card","value":"453985******7062 09/24 (Visa Credit)"},{"order":9,"label":"Auth Response","value":"Decline"},{"order":10,"label":"Authorisation Code","value":"OK2526"},{"order":11,"label":"Total Amount","value":"USD 1.01"}],"customFields":[],"iccData":[],"footer":"PLEASE RETAIN FOR YOUR RECORDS"},{"copy":"CARD_ACCEPTOR_COPY","header":"MERCHANT COPY","merchantDetails":[{"order":0,"label":"Company","value":"Thrifty Consulting"},{"order":1,"label":"Address","value":"Test, Test, United States"},{"order":2,"label":"Phone","value":"1234567890"}],"transactionData":[{"order":0,"label":"Cardholder Name","value":"Longbob Longsen"},{"order":1,"label":"Card acceptor number","value":"RCTST0000006138"},{"order":2,"label":"Terminal ID","value":"00000001"},{"order":3,"label":"Order ID","value":"168088616547"},{"order":4,"label":"Unique Ref","value":"IEFD1FTTUP"},{"order":5,"label":"Date/Time","value":"Apr 7, 2023 10:49:25 AM"},{"order":6,"label":"Transaction Data Source","value":"KEYED"},{"order":7,"label":"Transaction","value":"Purchase"},{"order":8,"label":"Type","value":"Customer Not Present"},{"order":9,"label":"Status","value":"DECLINED"},{"order":10,"label":"Card","value":"453985******7062 09/24 (Visa Credit)"},{"order":11,"label":"Auth Response","value":"Decline"},{"order":12,"label":"Authorisation Code","value":"OK2526"},{"order":13,"label":"Total Amount","value":"USD 1.01"}],"customFields":[],"iccData":[],"footer":"I WILL NOT BE CHARGED FOR THIS TRANSACTION"}],"links":[{"rel":"refund","method":"POST","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/IEFD1FTTUP/refunds"},{"rel":"update","method":"PATCH","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/IEFD1FTTUP"},{"rel":"capture","method":"PATCH","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/IEFD1FTTUP/capture"},{"rel":"self","method":"GET","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/IEFD1FTTUP"},{"rel":"reverse","method":"PATCH","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/IEFD1FTTUP/reverse"}]}
    )
  end

  def successful_capture_response
    %(
      {"uniqueReference":"L5T7R0NPZ4","terminal":"5304001","operator":"mark_dev","order":{"orderId":"168088625801","currency":"USD","totalAmount":1.00},"customerAccount":{"cardType":"Visa Credit","cardholderName":"Longbob Longsen","maskedPan":"453985******7062","expiryDate":"0924","entryMethod":"KEYED"},"securityCheck":{"cvvResult":"M","avsResult":"Y"},"transactionResult":{"type":"SALE","status":"READY","approvalCode":"OK2527","dateTime":"2023-04-07T10:50:59-06:00","currency":"USD","authorizedAmount":1.00,"resultCode":"A","resultMessage":"OK2527"},"additionalDataFields":[{"name":"ORDER_NUM","value":"04012881"}],"receipts":[{"copy":"CARDHOLDER_COPY","header":"CARDHOLDER COPY","merchantDetails":[{"order":0,"label":"Company","value":"Thrifty Consulting"},{"order":1,"label":"Address","value":"Test, Test, United States"},{"order":2,"label":"Phone","value":"1234567890"}],"transactionData":[{"order":0,"label":"Cardholder Name","value":"Longbob Longsen"},{"order":1,"label":"Card acceptor number","value":"***********6138"},{"order":2,"label":"Terminal ID","value":"****0001"},{"order":3,"label":"Date/Time","value":"Apr 7, 2023 10:50:59 AM"},{"order":4,"label":"Transaction Data Source","value":"KEYED"},{"order":5,"label":"Transaction","value":"Purchase"},{"order":6,"label":"Type","value":"Customer Not Present"},{"order":7,"label":"Status","value":"READY"},{"order":8,"label":"Card","value":"453985******7062 09/24 (Visa Credit)"},{"order":9,"label":"Auth Response","value":"OK2527"},{"order":10,"label":"Authorisation Code","value":"OK2527"},{"order":11,"label":"Amount","value":"USD 1.00"},{"order":12,"label":"Total Amount","value":"USD 1.00"}],"customFields":[],"iccData":[],"footer":"PLEASE RETAIN FOR YOUR RECORDS"},{"copy":"CARD_ACCEPTOR_COPY","header":"MERCHANT COPY","merchantDetails":[{"order":0,"label":"Company","value":"Thrifty Consulting"},{"order":1,"label":"Address","value":"Test, Test, United States"},{"order":2,"label":"Phone","value":"1234567890"}],"transactionData":[{"order":0,"label":"Cardholder Name","value":"Longbob Longsen"},{"order":1,"label":"Card acceptor number","value":"RCTST0000006138"},{"order":2,"label":"Terminal ID","value":"00000001"},{"order":3,"label":"Order ID","value":"168088625801"},{"order":4,"label":"Unique Ref","value":"L5T7R0NPZ4"},{"order":5,"label":"Date/Time","value":"Apr 7, 2023 10:50:59 AM"},{"order":6,"label":"Transaction Data Source","value":"KEYED"},{"order":7,"label":"Transaction","value":"Purchase"},{"order":8,"label":"Type","value":"Customer Not Present"},{"order":9,"label":"Status","value":"READY"},{"order":10,"label":"Card","value":"453985******7062 09/24 (Visa Credit)"},{"order":11,"label":"Auth Response","value":"OK2527"},{"order":12,"label":"Authorisation Code","value":"OK2527"},{"order":13,"label":"Amount","value":"USD 1.00"},{"order":14,"label":"Total Amount","value":"USD 1.00"}],"customFields":[],"iccData":[],"footer":"PLEASE DEBIT MY ACCOUNT WITH TOTAL SHOWN"}],"links":[{"rel":"refund","method":"POST","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/L5T7R0NPZ4/refunds"},{"rel":"update","method":"PATCH","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/L5T7R0NPZ4"},{"rel":"self","method":"GET","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/L5T7R0NPZ4"},{"rel":"reverse","method":"PATCH","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/L5T7R0NPZ4/reverse"}]}
    )
  end

  def failed_capture_response
    raise NotImplementedError
  end

  def successful_refund_response
    %(
      {"uniqueReference":"KUWGNJIJ0O","terminal":"5304001","operator":"mark_dev","orderId":"168082711542","refundReason":"Refund reason","customerAccount":{"cardType":"Visa Credit","cardholderName":"Longbob Longsen","maskedPan":"453985******7062","expiryDate":"0924","entryMethod":"KEYED"},"securityCheck":{"cvvResult":"M","avsResult":"Y"},"transactionResult":{"type":"SALE","status":"VOID","approvalCode":"OK2117","dateTime":"2023-04-06T18:25:16-06:00","currency":"USD","authorizedAmount":1.00,"resultCode":"A","resultMessage":"OK2117"},"additionalDataFields":[{"name":"ORDER_NUM","value":"04012578"},{"name":"ORDER_NUM","value":"04012578"}],"receipts":[{"copy":"CARDHOLDER_COPY","header":"CARDHOLDER COPY","merchantDetails":[{"order":0,"label":"Company","value":"Thrifty Consulting"},{"order":1,"label":"Address","value":"Test, Test, United States"},{"order":2,"label":"Phone","value":"1234567890"}],"transactionData":[{"order":0,"label":"Cardholder Name","value":"Longbob Longsen"},{"order":1,"label":"Card acceptor number","value":"***********6138"},{"order":2,"label":"Terminal ID","value":"****0001"},{"order":3,"label":"Date/Time","value":"Apr 6, 2023 6:25:16 PM"},{"order":4,"label":"Transaction Data Source","value":"KEYED"},{"order":5,"label":"Transaction","value":"Purchase"},{"order":6,"label":"Type","value":"Customer Not Present"},{"order":7,"label":"Status","value":"VOID"},{"order":8,"label":"Card","value":"453985******7062 09/24 (Visa Credit)"},{"order":9,"label":"Description","value":"Refund reason"},{"order":10,"label":"Auth Response","value":"OK2117"},{"order":11,"label":"Authorisation Code","value":"OK2117"},{"order":12,"label":"Total Amount","value":"USD 1.00"}],"customFields":[],"iccData":[],"footer":"PLEASE RETAIN FOR YOUR RECORDS"},{"copy":"CARD_ACCEPTOR_COPY","header":"MERCHANT COPY","merchantDetails":[{"order":0,"label":"Company","value":"Thrifty Consulting"},{"order":1,"label":"Address","value":"Test, Test, United States"},{"order":2,"label":"Phone","value":"1234567890"}],"transactionData":[{"order":0,"label":"Cardholder Name","value":"Longbob Longsen"},{"order":1,"label":"Card acceptor number","value":"RCTST0000006138"},{"order":2,"label":"Terminal ID","value":"00000001"},{"order":3,"label":"Order ID","value":"168082711542"},{"order":4,"label":"Unique Ref","value":"KUWGNJIJ0O"},{"order":5,"label":"Date/Time","value":"Apr 6, 2023 6:25:16 PM"},{"order":6,"label":"Transaction Data Source","value":"KEYED"},{"order":7,"label":"Transaction","value":"Purchase"},{"order":8,"label":"Type","value":"Customer Not Present"},{"order":9,"label":"Status","value":"VOID"},{"order":10,"label":"Card","value":"453985******7062 09/24 (Visa Credit)"},{"order":11,"label":"Description","value":"Refund reason"},{"order":12,"label":"Auth Response","value":"OK2117"},{"order":13,"label":"Authorisation Code","value":"OK2117"},{"order":14,"label":"Total Amount","value":"USD 1.00"}],"customFields":[],"iccData":[],"footer":"I WILL NOT BE CHARGED FOR THIS TRANSACTION"}],"links":[{"rel":"self","method":"GET","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/KUWGNJIJ0O"}]}
    )
  end

  def failed_refund_response
    raise NotImplementedError
  end

  def successful_void_response
    %(
      {"uniqueReference":"FLHDW7NR0J","terminal":"5304001","operator":"mark_dev","order":{"orderId":"168088654291","currency":"USD","totalAmount":1.00},"customerAccount":{"cardType":"Visa Credit","cardholderName":"Longbob Longsen","maskedPan":"453985******7062","expiryDate":"0924","entryMethod":"KEYED"},"securityCheck":{"cvvResult":"M","avsResult":"Y"},"transactionResult":{"type":"SALE","status":"VOID","approvalCode":"OK2529","dateTime":"2023-04-07T10:55:44-06:00","currency":"USD","authorizedAmount":1.00,"resultCode":"A","resultMessage":"OK2529"},"additionalDataFields":[{"name":"ORDER_NUM","value":"04012883"}],"receipts":[{"copy":"CARDHOLDER_COPY","header":"CARDHOLDER COPY","merchantDetails":[{"order":0,"label":"Company","value":"Thrifty Consulting"},{"order":1,"label":"Address","value":"Test, Test, United States"},{"order":2,"label":"Phone","value":"1234567890"}],"transactionData":[{"order":0,"label":"Cardholder Name","value":"Longbob Longsen"},{"order":1,"label":"Card acceptor number","value":"***********6138"},{"order":2,"label":"Terminal ID","value":"****0001"},{"order":3,"label":"Date/Time","value":"Apr 7, 2023 10:55:44 AM"},{"order":4,"label":"Transaction Data Source","value":"KEYED"},{"order":5,"label":"Transaction","value":"Purchase"},{"order":6,"label":"Type","value":"Customer Not Present"},{"order":7,"label":"Status","value":"VOID"},{"order":8,"label":"Card","value":"453985******7062 09/24 (Visa Credit)"},{"order":9,"label":"Auth Response","value":"OK2529"},{"order":10,"label":"Authorisation Code","value":"OK2529"},{"order":11,"label":"Amount","value":"USD 1.00"},{"order":12,"label":"Total Amount","value":"USD 1.00"}],"customFields":[],"iccData":[],"footer":"PLEASE RETAIN FOR YOUR RECORDS"},{"copy":"CARD_ACCEPTOR_COPY","header":"MERCHANT COPY","merchantDetails":[{"order":0,"label":"Company","value":"Thrifty Consulting"},{"order":1,"label":"Address","value":"Test, Test, United States"},{"order":2,"label":"Phone","value":"1234567890"}],"transactionData":[{"order":0,"label":"Cardholder Name","value":"Longbob Longsen"},{"order":1,"label":"Card acceptor number","value":"RCTST0000006138"},{"order":2,"label":"Terminal ID","value":"00000001"},{"order":3,"label":"Order ID","value":"168088654291"},{"order":4,"label":"Unique Ref","value":"FLHDW7NR0J"},{"order":5,"label":"Date/Time","value":"Apr 7, 2023 10:55:44 AM"},{"order":6,"label":"Transaction Data Source","value":"KEYED"},{"order":7,"label":"Transaction","value":"Purchase"},{"order":8,"label":"Type","value":"Customer Not Present"},{"order":9,"label":"Status","value":"VOID"},{"order":10,"label":"Card","value":"453985******7062 09/24 (Visa Credit)"},{"order":11,"label":"Auth Response","value":"OK2529"},{"order":12,"label":"Authorisation Code","value":"OK2529"},{"order":13,"label":"Amount","value":"USD 1.00"},{"order":14,"label":"Total Amount","value":"USD 1.00"}],"customFields":[],"iccData":[],"footer":"I WILL NOT BE CHARGED FOR THIS TRANSACTION"}],"links":[{"rel":"self","method":"GET","href":"https://testpayments.worldnettps.com/merchant/api/v1/transaction/payments/FLHDW7NR0J"}]}
    )  
  end

  def failed_void_response
    raise NotImplementedError
  end
end
