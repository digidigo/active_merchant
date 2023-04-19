require 'ipaddr'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class FluidpayGateway < Gateway
      VERIFICATION_AMOUNT_IN_CENTS = 100

      UnsupportedActionError = Class.new(StandardError)
      Invalid3DSVersionError = Class.new(StandardError)

      self.test_url = 'https://sandbox.fluidpay.com/api'
      self.live_url = 'https://app.fluidpay.com/api'

      self.supported_countries = ['US']
      self.default_currency = 'USD'
      self.supported_cardtypes = [:visa, :master, :american_express, :discover]
      self.money_format = :cents

      self.homepage_url = 'https://www.fluidpay.com/'
      self.display_name = 'Fluid Pay'

      ACTIONS = {
        authorize: 'authorize',
        capture: 'capture',
        purchase: 'purchase',
        refund: 'refund',
        verify: 'verify',
        void: 'void'
      }

      STANDARD_ERROR_CODE_MAPPING = {
        223 => STANDARD_ERROR_CODE[:expired_card],
        225 => STANDARD_ERROR_CODE[:invalid_cvc],
        240 => STANDARD_ERROR_CODE[:call_issuer],
        250 => STANDARD_ERROR_CODE[:pickup_card],
        251 => STANDARD_ERROR_CODE[:pickup_card],
        252 => STANDARD_ERROR_CODE[:pickup_card],
        253 => STANDARD_ERROR_CODE[:pickup_card],
        400 => STANDARD_ERROR_CODE[:processing_error],
        410 => STANDARD_ERROR_CODE[:config_error]
      }

      def initialize(options={})
        requires!(options, :api_key)
        super
      end

      def purchase(money, payment, options={})
        requires!(options, :order_id)

        post = {}
        add_invoice(post, money, options)
        add_payment(post, payment, options)
        add_3ds(post, payment, options)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit(ACTIONS[:purchase], post)
      end

      def authorize(money, payment, options={})
        post = {}

        add_invoice(post, money, options)
        add_payment(post, payment, options)
        add_address(post, payment, options)
        add_customer_data(post, options)

        commit(ACTIONS[:authorize], post)
      end

      def capture(money, authorization, options={})
        options[:transaction_id] = authorization

        post = { amount: amount(money) }

        commit(ACTIONS[:capture], post, options)
      end

      def refund(money, authorization, options={})
        options[:transaction_id] = authorization

        post = {
          amount: amount(money),
        }

        commit(ACTIONS[:refund], post, options)
      end

      def void(authorization, options={})
        options[:transaction_id] = authorization

        commit(ACTIONS[:void], {}, options)
      end

      def verify(credit_card, options={})
        post = {}

        add_invoice(post, VERIFICATION_AMOUNT_IN_CENTS, options)
        add_payment(post, credit_card, options)
        add_address(post, credit_card, options)
        add_customer_data(post, options)

        commit(ACTIONS[:verify], post)
      end

      def supports_scrubbing?
        false
      end

      def scrub(transcript)
        raise NotImplementedError
      end

      private

      def add_customer_data(post, options)
        if options[:email]
          post[:email_address] = options[:email]

          post[:billing_address] ||= {}
          post[:billing_address].merge!({ email: options[:email] })
        end

        post[:ip_address] = options[:ip] if options[:ip]
      end

      def add_address(post, creditcard, options)
        address = options[:billing_address] || options[:address]
        return unless address

        billing_address = {}

        first_name = firstname(creditcard)
        billing_address[:first_name] = first_name if first_name

        last_name = lastname(creditcard)
        billing_address[:last_name] = last_name if last_name

        billing_address[:address_line_1] = address[:address1] if address[:address1]
        billing_address[:address_line_2] = address[:address2] if address[:address2]
        billing_address[:city] = address[:city] if address[:city]
        billing_address[:state] = address[:state] if address[:state]
        billing_address[:country] = address[:country] if address[:country] # ISO 3166-1-alpha-2 code.
        billing_address[:postal_code] = address[:zip] if address[:zip]

        if billing_address.size > 0
          post[:billing_address] ||= {}
          post[:billing_address].merge!(billing_address)
        end
      end

      def add_invoice(post, money, options)
        post[:order_id] = options[:order_id]
        post[:currency] = (options[:currency] || currency(money))
        post[:amount] = amount(money)
        post[:description] = description_for(options[:description]) if options[:description]
        post[:billing_method] = options[:billing_method] if options[:billing_method]
        post[:descriptor] = options[:descriptor] if options[:descriptor]
      end

      def add_payment(post, payment, options)
        post[:payment_method] ||= {}
        post[:payment_method][:card] ||= {}
        post[:payment_method][:card][:entry_type] = 'keyed'
        post[:payment_method][:card][:number] = payment.number
        post[:payment_method][:card][:expiration_date] = expdate(payment)
        post[:payment_method][:card][:cvv] = payment.verification_value if payment.verification_value

        # CIT/MIT
        post[:card_on_file_indicator] = options[:card_on_file_indicator] if options[:card_on_file_indicator] # "C" = general "R" = recurring "I" = installment
        post[:initiated_by] = options[:initiated_by] if options[:initiated_by] # "customer" or "merchant"
        post[:initial_transaction_id] = options[:initial_transaction_id] if options[:initial_transaction_id] # FluidPay initial transaction id
        post[:stored_credential_indicator] = options[:stored_credential_indicator] if options[:stored_credential_indicator] # "stored" or "used"
      end

      def add_3ds(post, payment, options)
        if options[:three_d_secure]
          requires!(options[:three_d_secure], :eci)

          post[:payment_method] ||= {}
          post[:payment_method][:card] ||= {}
          post[:payment_method][:card][:cardholder_authentication] ||= {}

          post[:payment_method][:card][:cardholder_authentication][:eci] = options[:three_d_secure][:eci]
          post[:payment_method][:card][:cardholder_authentication][:xid] = options[:three_d_secure][:xid] if options[:three_d_secure][:xid]
          post[:payment_method][:card][:cardholder_authentication][:cavv] = options[:three_d_secure][:cavv] if options[:three_d_secure][:cavv]
          post[:payment_method][:card][:cardholder_authentication][:version] = protocol_version_for(options[:three_d_secure][:version]) if options[:three_d_secure][:version]
          post[:payment_method][:card][:cardholder_authentication][:ds_transaction_id] = options[:three_d_secure][:ds_transaction_id] if options[:three_d_secure][:ds_transaction_id]
          post[:payment_method][:card][:cardholder_authentication][:acs_transaction_id] = options[:three_d_secure][:acs_transaction_id] if options[:three_d_secure][:acs_transaction_id]
        end
      end

      def parse(body)
        JSON.parse(body)
      end

      def commit(action, parameters, options = {})
        http_method = options.fetch(:http_method, :post)
        response = parse(ssl_request(http_method, url_for(action, parameters, options), post_data(action, parameters), standard_request_headers))

        Response.new(
          success_from(action, response),
          message_from(action, response),
          response,
          authorization: authorization_from(response),
          avs_result: AVSResult.new(code: avs_result_from(response)),
          cvv_result: CVVResult.new(cvv_result_from(response)),
          test: test?,
          error_code: error_code_from(action, response)
        )
      end

      def success_from(action, response)
        case action
        when ACTIONS[:void]
          response['status'] == 'success' && response.dig('data', 'type') == 'void'
        else
          response.dig('data', 'response_code') == 100
        end
      end

      def message_from(action, response)
        case action
        when ACTIONS[:void]
          response.dig('data', 'type')
        else
          response.dig('data', 'response')
        end
      end

      def authorization_from(response)
        response.dig('data', 'id')
      end

      def avs_result_from(response)
        response.dig('data', 'response_body', 'card', 'avs_response_code')
      end

      def cvv_result_from(response)
        response.dig('data', 'response_body', 'card', 'cvv_response_code')
      end

      def post_data(action, parameters = {})
        case action
        when ACTIONS[:authorize]
          parameters[:type] = 'authorize'
        when ACTIONS[:purchase]
          parameters[:type] = "sale"
        when ACTIONS[:verify]
          parameters[:type] = "verification"
        end

        JSON.dump(parameters)
      end

      def error_code_from(action, response)
        unless success_from(action, response)
          if (response_code = response.dig('data', 'response_code'))
            standard_code = STANDARD_ERROR_CODE_MAPPING[response_code]

            standard_code ||= case response_code
                              when 200..399
                                STANDARD_ERROR_CODE[:card_declined]
                              end
          end
        end
      end

      def firstname(payment)
        payment.first_name.slice(0, 50)
      end

      def lastname(payment, max_length = 60)
        payment.last_name.slice(0, 50)
      end

      def expdate(payment)
        sprintf('%02d/%02d', payment.month, payment.year % 100)
      end

      def url_for(action, parameters, options = {})
        base_url = (test? ? test_url : live_url)

        case action
        when ACTIONS[:authorize], ACTIONS[:purchase], ACTIONS[:verify]
          "#{base_url}/transaction"
        when ACTIONS[:capture]
          requires!(options, :transaction_id)
          "#{base_url}/transaction/#{options[:transaction_id]}/capture"
        when ACTIONS[:refund]
          requires!(options, :transaction_id)
          "#{base_url}/transaction/#{options[:transaction_id]}/refund"
        when ACTIONS[:void]
          requires!(options, :transaction_id)
          "#{base_url}/transaction/#{options[:transaction_id]}/void"
        else
          raise UnsupportedActionError.new(action)
        end
      end

      def standard_request_headers
        {
          Accept: 'application/json',
          Authorization: options[:api_key],
          "Content-Type": 'application/json'
        }
      end

      def description_for(description)
        description.slice(0, 1024)
      end

      def protocol_version_for(version)
        case version
        when /2\..+/
          '2'
        when /1\..+/
          '1'
        else
          raise Invalid3DSVersionError
        end
      end

      def amount(*)
        super.to_i
      end
    end
  end
end
