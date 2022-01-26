# frozen_string_literal: true

module OrkaAPI
  # Base error class.
  class Error < ::StandardError; end

  # This error is thrown if an endpoint requests an auth mechanism which we do not have credentials for.
  class AuthConfigurationError < Error; end

  # This error is thrown if a specific resource is requested but it was not found in the Orka backend.
  class ResourceNotFoundError < Error; end

  # This error is thrown if the client receives data from the server it does not recognise. This is typically
  # indicative of a bug or a feature not yet implemented.
  class UnrecognisedStateError < Error; end
end
