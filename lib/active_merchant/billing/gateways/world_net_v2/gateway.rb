require 'active_merchant/billing/gateways/world_net_v2/token'
require 'ipaddr'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module WorldNetV2 #:nodoc:
      class Gateway < Gateway
        UnsupportedActionError = Class.new(StandardError)
        Invalid3DSVersionError = Class.new(StandardError)

        self.test_url = 'https://testpayments.worldnettps.com/merchant/api/v1'
        self.live_url = 'https://payments.worldnettps.com/merchant/api/v1'

        self.supported_countries = ['US']
        self.default_currency = 'USD'
        self.supported_cardtypes = [:visa, :master, :american_express, :discover]

        self.homepage_url = 'http://www.worldnetpayments.com/'
        self.display_name = 'Worldnet V2'

        ACTIONS = {
          authorize: 'authorize',
          capture: 'capture',
          purchase: 'purchase',
          refund: 'refund',
          void: 'void'
        }

        STANDARD_ERROR_CODE_MAPPING = {
          'D' => Gateway::STANDARD_ERROR_CODE[:card_declined],
          'E' => nil,
          'P' => nil,
          'R' => Gateway::STANDARD_ERROR_CODE[:call_issuer],
          'C' => nil
        }

        def self.token(options = {})
          WorldNetV2::Token.fetch(options)
        end

        def initialize(options={})
          requires!(options, :merchant_api_key)
          super
        end

        def purchase(money, payment, options={})
          requires!(options, :order_id)

          post = {}
          add_invoice(post, money, options)
          add_payment(post, payment)
          add_3ds(post, payment, options)
          add_address(post, payment, options)
          add_customer_data(post, options)

          commit(ACTIONS[:purchase], post)
        end

        def authorize(money, payment, options={})
          post = {}

          add_invoice(post, money, options)
          add_payment(post, payment)
          add_address(post, payment, options)
          add_customer_data(post, options)

          commit(ACTIONS[:authorize], post)
        end

        def capture(money, authorization, options={})
          options[:http_method] = :patch
          options[:uniqueReference] = authorization

          post = { captureAmount: amount(money) }

          commit(ACTIONS[:capture], post, options)
        end

        def refund(money, authorization, options={})
          reason = options.fetch(:reason, "Refund #{authorization}")
          options[:uniqueReference] = authorization

          post = {
            refundAmount: amount(money),
            refundReason: refund_reason_for(reason)
          }

          commit(ACTIONS[:refund], post, options)
        end

        def void(authorization, options={})
          options[:http_method] = :patch
          options[:uniqueReference] = authorization

          commit(ACTIONS[:void], {}, options)
        end

        def verify(credit_card, options={})
          MultiResponse.run(:use_first_response) do |r|
            r.process { authorize(100, credit_card, options) }
            r.process(:ignore_result) { void(r.authorization, options) }
          end
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
            post[:customer] ||= {}
            post[:customer][:email] = options[:email]
          end

          if options[:ip] && (ip = IPAddr.new(options[:ip]) rescue nil)
            post[:ipAddress] ||= {}

            if ip.ipv4?
              post[:ipAddress][:ipv4] = options[:ip]
            elsif ip.ipv6?
              post[:ipAddress][:ipv6] = options[:ip]
            end
          end
        end

        def add_address(post, creditcard, options)
          address = options[:billing_address] || options[:address]
          return unless address

          billing_address = {}
          billing_address[:line1] = address[:address1] if address[:address1]
          billing_address[:line2] = address[:address2] if address[:address2]
          billing_address[:city] = address[:city] if address[:city]
          billing_address[:state] = address[:state] if address[:state]
          billing_address[:country] = address[:country] if address[:country] # ISO 3166-1-alpha-2 code.
          billing_address[:postalCode] = address[:zip] if address[:zip]

          if billing_address.size > 0
            post[:customer] ||= {}
            post[:customer][:billingAddress] = billing_address
          end
        end

        def add_invoice(post, money, options)
          post[:order] ||= {}
          post[:order][:orderId] = options[:order_id]
          post[:order][:currency] = (options[:currency] || currency(money))
          post[:order][:totalAmount] = amount(money)
          post[:order][:description] = description_for(options[:description]) if options[:description]
        end

        def add_payment(post, payment)
          post[:customerAccount] ||= {}
          post[:customerAccount][:payloadType] = 'KEYED'
          post[:customerAccount][:cardholderName] = cardholdername(payment)

          post[:customerAccount][:cardDetails] ||= {}
          post[:customerAccount][:cardDetails][:cardNumber] = payment.number
          post[:customerAccount][:cardDetails][:expiryDate] = expdate(payment)
          post[:customerAccount][:cardDetails][:cvv] = payment.verification_value if payment.verification_value
        end

        def add_3ds(post, payment, options)
          if options[:three_d_secure]
            requires!(options[:three_d_secure], :eci)

            post[:threeDSecure] ||= {}
            post[:threeDSecure][:serviceProvider] = 'THIRD_PARTY'
            post[:threeDSecure][:eci] = options[:three_d_secure][:eci]
            post[:threeDSecure][:xid] = xid_for(options[:three_d_secure][:xid]) if options[:three_d_secure][:xid]
            post[:threeDSecure][:cavv] = cavv_for(options[:three_d_secure][:cavv]) if options[:three_d_secure][:cavv]
            post[:threeDSecure][:protocolVersion] = protocol_version_for(options[:three_d_secure][:version]) if options[:three_d_secure][:version]
            post[:threeDSecure][:dsTransactionId] = ds_transaction_id_for(options[:three_d_secure][:ds_transaction_id]) if options[:three_d_secure][:ds_transaction_id]
          end
        end

        def parse(body)
          JSON.parse(body)
        end

        def commit(action, parameters, options = {})
          http_method = options.fetch(:http_method, :post)
          response = parse(ssl_request(http_method, url_for(action, parameters, options), post_data(action, parameters), standard_request_headers))

          Response.new(
            success_from(response),
            message_from(response),
            response,
            authorization: authorization_from(response),
            avs_result: AVSResult.new(code: avs_result_from(response)),
            cvv_result: CVVResult.new(cvv_result_from(response)),
            test: test?,
            error_code: error_code_from(response)
          )
        end

        def success_from(response)
          response.dig('transactionResult', 'resultCode') == 'A'
        end

        def message_from(response)
          response.dig('transactionResult', 'status')
        end

        def authorization_from(response)
          response['uniqueReference']
        end

        def avs_result_from(response)
          response.dig('securityCheck', 'avsResult')
        end

        def cvv_result_from(response)
          response.dig('securityCheck', 'cvvResult')
        end

        def post_data(action, parameters = {})
          case action
          when ACTIONS[:authorize]
            parameters[:channel] = 'WEB'
            parameters[:terminal] = token[:terminal]
            parameters[:autoCapture] = false
          when ACTIONS[:purchase]
            parameters[:channel] = 'WEB'
            parameters[:terminal] = token[:terminal]
            parameters[:autoCapture] = true
            parameters[:processAsSale] = true
          end

          JSON.dump(parameters)
        end

        def error_code_from(response)
          unless success_from(response)
            STANDARD_ERROR_CODE_MAPPING[response.dig('transactionResult', 'resultCode')]
          end
        end

        def token
          self.class.token(options)
        end

        def cardholdername(payment, max_length = 60)
          [payment.first_name, payment.last_name].join(' ').slice(0, max_length)
        end

        def expdate(payment)
          sprintf('%02d%02d', payment.month, payment.year % 100)
        end

        def url_for(action, parameters, options = {})
          base_url = (test? ? test_url : live_url)

          case action
          when ACTIONS[:authorize], ACTIONS[:purchase]
            "#{base_url}/transaction/payments"
          when ACTIONS[:capture]
            requires!(options, :uniqueReference)
            "#{base_url}/transaction/payments/#{options[:uniqueReference]}/capture"
          when ACTIONS[:refund]
            requires!(options, :uniqueReference)
            "#{base_url}/transaction/payments/#{options[:uniqueReference]}/refunds"
          when ACTIONS[:void]
            requires!(options, :uniqueReference)
            "#{base_url}/transaction/payments/#{options[:uniqueReference]}/reverse"
          else
            raise UnsupportedActionError.new(action)
          end
        end

        def standard_request_headers
          {
            Accept: 'application/json',
            "Accept-Language": 'en',
            Authorization: "Bearer #{token[:token]}",
            "Content-Type": 'application/json'
          }
        end

        def description_for(description)
          description.slice(0, 1024)
        end

        def refund_reason_for(reason)
          reason.slice(0, 100)
        end

        def xid_for(xid)
          xid.slice(0, 50)
        end

        def cavv_for(cavv)
          cavv.slice(0, 50)
        end

        def protocol_version_for(version)
          case version
          when /2\..+/
            'VERSION_2'
          when /1\..+/
            'VERSION_1'
          else
            raise Invalid3DSVersionError
          end 
        end

        def ds_transaction_id_for(ds_transaction_id)
          ds_transaction_id.slice(0, 36)
        end
      end
    end
  end
end
