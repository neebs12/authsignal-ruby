require "faraday"
require "faraday/retry"
require "authsignal/version"
require "authsignal/client"
require "authsignal/configuration"
require "authsignal/api_error"
require "authsignal/middleware/json_response"
require "authsignal/middleware/json_request"

module Authsignal
    NON_API_METHODS = [:setup, :configuration, :default_configuration]

    class << self
        attr_writer :configuration

        def setup
            yield(configuration)
        end

        def configuration
            @configuration ||= Authsignal::Configuration.new
        end

        def default_configuration
            configuration.defaults
        end

        def get_user(user_id:, redirect_url: nil)
            response = Client.new.get_user(user_id: user_id, redirect_url: redirect_url)

            handle_response(response)
        end

        def update_user(user_id:, user:)
            response = Client.new.update_user(user_id: user_id, user: user)

            handle_response(response)
        end

        def delete_user(user_id:)
            response = Client.new.delete_user(user_id: user_id)

            handle_response(response)
        end

        def get_action(user_id:, action:, idempotency_key:)
            response = Client.new.get_action(user_id, action, idempotency_key)

            handle_response(response)
        end

        def enroll_verified_authenticator(user_id:, authenticator:)
            response = Client.new.enroll_verified_authenticator(user_id, authenticator)

            handle_response(response)
        end

        def delete_authenticator(user_id:, user_authenticator_id: )
            response = Client.new.delete_authenticator(user_id: user_id, user_authenticator_id: user_authenticator_id)

            handle_response(response)
        end

        def track(event, options={})
            raise ArgumentError, "Action Code is required" unless event[:action].to_s.length > 0
            raise ArgumentError, "User ID value" unless event[:user_id].to_s.length > 0

            response = Client.new.track(event)
            handle_response(response)
        end

        def validate_challenge(token:, user_id: nil, action: nil)
            response = Client.new.validate_challenge(user_id: user_id, token: token, action: action)
            
            handle_response(response)
        end

        private

        def handle_response(response)
            if response.success?
                handle_success_response(response)
            else
                handle_error_response(response)
            end
        end

        def handle_success_response(response)
            response.body.merge(success?: true)
        end

        def handle_error_response(response)
            case response.body
            when Hash
                response.body.merge(status: response.status, success?: false)
            else
                { status: response&.status || 500, success?: false }
            end
        end
    end

    methods = Authsignal.singleton_class.public_instance_methods(false)
    (methods - NON_API_METHODS).each do |method|
        define_singleton_method("#{method}!") do |*args, **kwargs|
            send(method, *args, **kwargs).tap do |response|
                status = response[:status]
                err = response[:error]
                desc = response[:error_description]

                raise ApiError.new(err, status, err, desc) unless response[:success?]
            end
        end
    end
end
