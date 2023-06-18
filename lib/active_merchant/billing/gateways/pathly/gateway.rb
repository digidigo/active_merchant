require 'active_merchant/billing/gateways/pathly/token'
require 'ipaddr'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Pathly #:nodoc:
      class Gateway < Gateway
        UnsupportedActionError = Class.new(StandardError)

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

          if( payment.verification_value ) 
            # create customer and card with given customer id and card id
            create_customer(payment, options)
            create_card(payment, options.merge(card_id: options[:payment_method_id]))
          end


          post ={}
          post[:id] = options[:id] if options[:id]
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
        
          commit(ACTIONS[:purchase], post, options)
         

        end

        def refund(money, authorization, options={})

          requires!(options, :charge_id)
          requires!(options, :reason)
          requires!(authorization)
          post = options.merge(idempotency_key: authorization)

          post[:id] = options[:id] if options[:id]

          commit(ACTIONS[:refund], post, options)
        end

        def void(authorization, options={})
          refund(0, authorization, options)
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
# }         `
        def create_card( payment, options={})
          post = {}
          post[:customer_id] = options[:customer_id]
          #rais and error if customer_id is not present
          raise ArgumentError.new("customer_id is required") unless post[:customer_id]
          
          post[:id] = options[:card_id] || SecureRandom.uuid
          
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

        def url_for(action, parameters, options = {})
          base_url = (test? ? test_url : live_url)

          case action
          when 'customer'
            "#{base_url}/customers"
          when 'create_card'
            "#{base_url}/payment-methods/cards"  
          when ACTIONS[:purchase]
            "#{base_url}/charges"
          when ACTIONS[:refund]
            "#{base_url}/refunds"  
          when ACTIONS[:void]
            "#{base_url}/refunds"  
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
          description.slice(0, 255)
        end

        def refund_reason_for(reason)
          reason.slice(0, 100)
        end
      end
    end
  end
end
