# frozen_string_literal: true

module OrkaAPI
  module Models
    # A particular log event.
    class LogEntry
      # Information on the request element of a log event.
      class Request
        # @return [Hash] The body of the request.
        attr_reader :body

        # @return [Hash{String => String}] The headers of the request.
        attr_reader :headers

        # @return [String] The HTTP method used for the request.
        attr_reader :method

        # @return [String] The request URL.
        attr_reader :url

        # @api private
        # @param [Hash] hash
        def initialize(hash)
          @body = hash["body"]
          @headers = hash["headers"]
          @method = hash["method"]
          @url = hash["url"]
        end
      end

      # Information on the response element of a log event.
      class Response
        # @return [Hash] The body of the response.
        attr_reader :body

        # @return [Hash{String => String}] The headers of the response.
        attr_reader :headers

        # @return [Integer] The resultant HTTP status code of the response.
        attr_reader :status_code

        # @api private
        # @param [Hash] hash
        def initialize(hash)
          @body = hash["body"]
          @headers = hash["headers"]
          @status_code = hash["statusCode"]
        end
      end

      # Information on the user responsible for the log event.
      class User
        # @return [String] The user's email.
        attr_reader :email

        # @return [String] The user's ID.
        attr_reader :id

        # @api private
        # @param [Hash] hash
        def initialize(hash)
          @email = hash["email"]
          @id = hash["id"]
        end
      end

      # @return [DateTime] The time the log entry was created.
      attr_reader :creation_time

      # @return [String] The ID of the log entry.
      attr_reader :id

      # @return [Request] The HTTP request made.
      attr_reader :request

      # @return [Response] The HTTP response returned.
      attr_reader :response

      # @return [LogEntry::User, nil] The user which performed the action, if authenticated.
      attr_reader :user

      # @api private
      # @param [Hash] hash
      def initialize(hash)
        raise UnrecognisedStateError, "Unknown log version." if hash["logVersion"] != "1.0"

        @creation_time = DateTime.iso8601(hash["createdAt"])
        @id = hash["id"]
        @request = Request.new(hash["request"])
        @response = Response.new(hash["response"])
        @user = if hash["user"].empty?
          nil
        else
          User.new(hash["user"])
        end
      end
    end
  end
end
