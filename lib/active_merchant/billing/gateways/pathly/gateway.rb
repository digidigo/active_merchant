require 'active_merchant/billing/gateways/pathly/token'
require 'ipaddr'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Pathly #:nodoc:
      class Gateway < Gateway
        UnsupportedActionError = Class.new(StandardError)
        Invalid3DSVersionError = Class.new(StandardError)

        self.test_url = 'https://sandbox-api.pathly.io'
        self.live_url = 'https://api.pathly.io/'

        self.supported_countries = ['US']
        self.default_currency = 'USD'
        self.money_format = :cents

        self.supported_cardtypes = [:visa, :master, :american_express, :discover]

        self.homepage_url = 'https://pathly.io/'
        self.display_name = 'Pathly'

        ACTIONS = {
          authorize: 'authorize',
          capture: 'capture',
          purchase: 'purchase',
          refund: 'refund',
          void: 'void',
          create_card: 'create_card'
        }

        STANDARD_ERROR_CODE_MAPPING = {
          'D' => Gateway::STANDARD_ERROR_CODE[:card_declined],
          'E' => nil,
          'P' => nil,
          'R' => Gateway::STANDARD_ERROR_CODE[:call_issuer],
          'C' => nil
        }

        def self.token(options = {})
          Pathly::Token.fetch(options)
        end

        def initialize(options={})
          requires!(options, :secret_key)
          requires!(options, :merchant_id)
          super
        end


  #  {
  #     "id": charge_id,
  #     "customer_id": customer_id,
  #     "payment_method_id": card_id,
  #     "amount": {
  #       "value": amount,
  #       "currency": "USD"
  #     },
  #     "shipping_details": {
  #       "name": "Louis Griffin",
  #       "address": {
  #         "country": "US",
  #         "line1": "Passatge sant pere",
  #         "line2": "Apartment 2",
  #         "zip": "83970",
  #         "city": "Pineda de mar",
  #         "state": "Barcelona"
  #       }
       
  #   },
  #    "success_url": "https://example.com/success",
  #       "fail_url": "https://example.com/failure"      
  # }     

        def purchase(money, payment, options={})

          post ={}
          post[:id] = options[:charge_id] if options[:charge_id]
          post[:customer_id] = options[:customer_id]
          post[:payment_method_id] = options[:payment_method_id]
          post[:amount] = {}
          post[:amount][:value] = amount(money).to_i
          post[:amount][:currency] = options[:currency] || currency(money)
          post[:shipping_details] = get_address_details(payment, options)
          post[:success_url] = "https://example.com/success"
          post[:fail_url] = "https://example.com/failure"
          if options[:cv2] || options[:dynamic_descriptor]
            card = { cv2: options[:cv2], dynamic_descriptor: options[:dynamic_descriptor] }
            post[:card] = card
          end

          requires!(post, :customer_id)
          requires!(post, :payment_method_id)
          requires!(post, :amount)
          requires!(post[:amount], :value)
          requires!(post[:amount], :currency)

          if( post[:shipping_details])
            requires!(post, :shipping_details)
            requires!(post[:shipping_details], :name)
            requires!(post[:shipping_details], :address)
            requires!(post[:shipping_details][:address], :country)
            requires!(post[:shipping_details][:address], :line1)
            requires!(post[:shipping_details][:address], :zip)
            requires!(post[:shipping_details][:address], :city)
            requires!(post[:shipping_details][:address], :state)
          end
        
          begin
            commit(ACTIONS[:purchase], post, options)
          rescue ResponseError => e
            error = JSON.parse(e.response.body)

            if e.response.code == '422'
              puts "error: #{error.to_yaml}"
            end
          end

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

# {
#   "id": "4620ff89-63ea-4b66-8966-49d51f9ca0d5",
#   "customer_id": "852b5367-ed81-450f-be9e-684a690fe1fe",
#   "number": "5488888888888888",
#   "exp_month": "12",
#   "exp_year": "2025",
#   "cvv": "123",
#   "billing_details": {
#     "name": "Louis Griffin",
#     "email": "foo@bar.com",
#     "phone_number": "3036187555",
#     "address": {
#       "country": "US",
#       "line1": "Passatge sant pere",
#       "line2": "Apartment 2",
#       "zip": "8397.0",
#       "city": "Pineda de mar",
#       "state": "Barcelona"
#     }
#   }
# }        
        def create_card( payment, options={})
          post = {}
          post[:customer_id] = options[:customer_id]
          #rais and error if customer_id is not present
          raise ArgumentError.new("customer_id is required") unless post[:customer_id]
          
          post[:id] = options[:id] || SecureRandom.uuid
          
          post[:number] = payment.number
          post[:exp_month] = payment.month.to_s.rjust(2, '0')  # => "07"

          post[:exp_year] = payment.year.to_s
          post[:cvv] = payment.verification_value

          post[:billing_details] = get_address_details(payment, options)
    
          commit(ACTIONS[:create_card], post)
        end

 

        # Specific to Pathly 

        def create_customer(payment, options={})
          post = {}
          post[:id] = options[:customer_id] || SecureRandom.uuid
          post[:first_name] = options[:first_name] || payment&.first_name
          post[:last_name] = options[:last_name] || payment&.last_name

          commit('customer', post)
        end


        def supports_scrubbing?
          false
        end

        def scrub(transcript)
          raise NotImplementedError
        end

        private

        # def add_customer_data(post, options)
        #   if options[:email]
        #     post[:customer] ||= {}
        #     post[:customer][:email] = options[:email]
        #   end

        #   if options[:ip] && (ip = IPAddr.new(options[:ip]) rescue nil)
        #     post[:ipAddress] ||= {}

        #     if ip.ipv4?
        #       post[:ipAddress][:ipv4] = options[:ip]
        #     elsif ip.ipv6?
        #       post[:ipAddress][:ipv6] = options[:ip]
        #     end
        #   end
        # end

#        "billing_details": {
# #     "name": "Louis Griffin",
# #     "email": "foo@bar.com",
# #     "phone_number": "3036187555",
# #     "address": {
# #       "country": "US",
# #       "line1": "Passatge sant pere",
# #       "line2": "Apartment 2",
# #       "zip": "8397.0",
# #       "city": "Pineda de mar",
# #       "state": "Barcelona"
# #     }
# #   }
        def get_address(creditcard, options)
          address = options[:billing_address] || options[:address]
          
          billing_address = {}

          if( address)
            billing_address[:line1] = address[:address1] if address[:address1]
            billing_address[:line2] = address[:address2] if address[:address2]
            billing_address[:city] = address[:city] if address[:city]
            billing_address[:state] = address[:state] if address[:state]
            billing_address[:country] = address[:country] if address[:country] # ISO 3166-1-alpha-2 code.
            billing_address[:zip] = address[:zip] if address[:zip]
          end
          
          billing_address.empty? ? nil :  billing_address
        end

        def get_address_details(creditcard, options)
          billing_details = {}
          billing_details[:address] = get_address(creditcard, options)

          billing_details[:name] = cardholdername(creditcard)

          billing_details[:email] = options[:email] if options[:email]
          billing_details[:phone_number] = options[:phone_number] if options[:phone_number]

          billing_details[:address].nil? ? nil :  billing_details
        end

        # def add_address(post, creditcard, options)
        #   address = options[:billing_address] || options[:address]
        #   return unless address

        #   billing_address = {}
        #   billing_address[:line1] = address[:address1] if address[:address1]
        #   billing_address[:line2] = address[:address2] if address[:address2]
        #   billing_address[:city] = address[:city] if address[:city]
        #   billing_address[:state] = address[:state] if address[:state]
        #   billing_address[:country] = address[:country] if address[:country] # ISO 3166-1-alpha-2 code.
        #   billing_address[:postalCode] = address[:zip] if address[:zip]

        #   if billing_address.size > 0
        #     post[:customer] ||= {}
        #     post[:customer][:billingAddress] = billing_address
        #   end
        # end

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
          begin
            http_method = options.fetch(:http_method, :post)
            http_response = ssl_request(http_method, url_for(action, parameters, options), post_data(action, parameters), standard_request_headers)
            puts "Resposne: \n #{http_response.to_yaml}"  if( test?)

            response = parse(http_response)

            if( redirect_status?(response))
              response.merge!('redirect_required' => true)
              redirect_url = redirect_url_from(response)
              if(redirect_url)
                response.merge!('redirect_url' => redirect_url)
              end
            end

            response =  Response.new(
              success_from(response),
              message_from(response),
              response,
              test: test?,
              error_code: error_code_from(response),
            )

          rescue ActiveMerchant::ResponseError => e
           
            puts "Error: \n #{e.to_yaml}"  if( test?)
            response = parse(e.response&.body)

            response = Response.new(
                    success_from(response),
                    error_message_from(response),
                    response,
                    test: test?,
                    error_code: response['code']
                  )
          end

          response
        end

        def success_from(response)
          response && [200,202].include?(response['code'])
        end

        def redirect_status?(response)
          response && response['code'] == 202
        end

        def message_from(response)
          response['message']
        end

        def error_message_from(response)
          data = response['data']
          return response["message"] unless data && data.is_a?(Hash) 
          data.map do |key,value| 
            "#{key}: #{value}"
          end.join(', ')
        end

        def redirect_url_from(response)
          data = response['data']
          response['data']['acs_url'] if data&.is_a?(Hash)
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
          response["error_code"]
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
          when 'customer'
            "#{base_url}/customers"
          when 'create_card'
            "#{base_url}/payment-methods/cards"  
          when ACTIONS[:authorize], ACTIONS[:purchase]
            "#{base_url}/charges"
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
