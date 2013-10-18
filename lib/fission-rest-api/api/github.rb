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
      msg.confirm!(:response_body => 'Job submitted for build')
    rescue MultiJson::DecodeError
      error 'Failed to parse JSON from request'
      msg.confirm!(:response_body => 'Invalid JSON data', :code => :bad_request)
    rescue => e
      error "Unknown error: #{e.class}: #{e}"
      debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
      msg.confirm!(:response_body => 'Unexpected error encountered', :code => :internal_server_error)
    end
  end

end
