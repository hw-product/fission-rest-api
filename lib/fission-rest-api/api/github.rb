require 'fission-rest-api/builder'
require 'multi_json'

Fission::RestApi.define do

  post %r{/github-build/?} do
    begin
      payload = symbolize_hash(MultiJson.load(request.body))
      debug "Received build info: #{payload}"
      payload = {
        :job => 'package_builder',
        :message_id => Celluloid.uuid,
        :github => payload
      }
      Celluloid::Actor[:fission_bus].transmit(
        payload, :validator
      )
      con.respond :ok, 'Job submitted for build'
    rescue MultiJson::DecodeError
      error 'Failed to parse JSON from request'
      con.respond :bad_request, 'Invalid JSON data'
    rescue => e
      error "Unknown error: #{e.class}: #{e}"
      debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
      con.respond :internal_server_error, 'Unexpected error encountered'
    end
  end

end
