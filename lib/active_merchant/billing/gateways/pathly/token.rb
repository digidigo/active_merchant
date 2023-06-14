require 'active_merchant/billing/base'
require 'active_merchant/posts_data'
require 'json'

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
          raise ArgumentError("Missing :secret_key!") if @secret_key.nil?
        end

        def fetch
          lock.synchronize { fetch_new! if token_expired? } if token_expired?
          self.class.token_data[secret_key]
        end

        private

        attr_reader :options, :secret_key

        def fetch_new!
          response = JSON.parse(ssl_get(url, { Authorization: "Basic #{secret_key}" }))

          terminal = response['allowedTerminals'][0]
          raise TerminalMissingError.new if terminal.nil?

          self.class.token_data[secret_key] = {
            token: response['token'],
            terminal: terminal,
            expires_at: Time.now + Integer(response['expiresIn']) * 3600
          }
        end

        def url
          if test?
            'https://sandbox-api.pathly.io/jwt/token'
          else
            'https://api.pathly.io/jwt/token'
          end
        end

        # Are we running in test mode?
        def test?
          (@options.has_key?(:test) ? @options[:test] : Base.test?)
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
