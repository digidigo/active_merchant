module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Pathly #:nodoc:
      class Token
        include PostsData

        TerminalMissingError = Class.new(StandardError)

        @lock = Mutex.new
        class_attribute :token_data, instance_accessor: false, default: {}

        def self.fetch(options = {})
          new(options).fetch
        end

        def self.lock
          @lock
        end

        def initialize(options = {})
          @options = options
          @secret_key = options.fetch(:secret_key, nil)
          @merchant_id = options.fetch(:merchant_id, nil)
          raise ArgumentError("Missing :secret_key!") if @secret_key.nil?
          raise ArgumentError("Missing :merchant_id!") if @merchant_id.nil?
        end

        def fetch
          lock.synchronize { fetch_new! if token_expired? } if token_expired?
          self.class.token_data[secret_key]
        end

        private

        attr_reader :options, :secret_key, :merchant_id

        def fetch_new!
          request_body = {
            merchant_id: merchant_id,
            key: secret_key
          }.to_json

            headers = {
              "Content-Type" => "application/json",
               "Accept" => "application/json"
            }
          response = JSON.parse(ssl_post(url, request_body,headers))

          self.class.token_data[secret_key] = {
            token: response['data']['token'],
            expires_at: Time.now + Integer(response['data']['expires_in'])
          }
        end

        def url
          'https://sandbox-api.pathly.io/jwt/token'
        end

        def token_expired?
          return true if token_expires_at.nil?
          Time.now > token_expires_at
        end

        def lock
          self.class.lock
        end

        def token_expires_at
          self.class.token_data.dig(secret_key, :expires_at)
        end
      end
    end
  end
end
