require 'multi_json'

Carnivore::PointBuilder.define do

  post %r{/github-build/?}, :workers => Carnivore::Config.get(:fission, :workers, :git_build) || 1 do |msg|
    begin
      payload = symbolize_hash(MultiJson.load(msg[:message][:body].to_s))
      payload = {
        :job => 'package_builder',
        :message_id => Celluloid.uuid,
        :github => payload
      }
      debug "Processing payload: #{payload}"
      Fission::Utils.transmit(:fission_package_builder, payload)
      msg[:message][:connection].respond :ok, 'Job submitted for build'
    rescue MultiJson::DecodeError
      error 'Failed to parse JSON from request'
      msg[:message][:connection].respond :bad_request, 'Invalid JSON data'
    rescue => e
      error "Unknown error: #{e.class}: #{e}"
      debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
      msg[:message][:connection].respond :internal_server_error, 'Unexpected error encountered'
    end
  end

end
