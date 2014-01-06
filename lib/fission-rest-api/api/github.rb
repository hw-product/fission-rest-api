require 'multi_json'
require 'fission/utils'

Carnivore::PointBuilder.define do

  post %r{/github-commit/?}, :workers => Carnivore::Config.get(:fission, :workers, :github_commit) || 1 do |msg, *args|
    begin
      job_name = Carnivore::Config.get(:fission, :rest_api, :github_commit, :job_name) || :router
      payload = MultiJson.load(msg[:message][:query][:payload])
      if(filter = msg[:message][:query][:filter])
        debug "Detected pkgr filter on #{msg} - #{filter}"
        unless(File.join('refs/head', filter) == payload['ref'])
          warn "Discarding #{msg} due to filter match failure. filter: #{filter} ref: #{payload['ref']}"
          msg.confirm!(:response_body => 'Job discared due to filter')
          return # short circuit
        end
      end
      payload = Fission::Utils.new_payload(job_name, :github => payload)
      debug "Processing payload: #{payload}"
      Fission::Utils.transmit(job_name, payload)
      msg.confirm!(:response_body => 'Job submitted for build')
    rescue MultiJson::DecodeError
      error 'Failed to parse JSON from request'
      msg.confirm!(:response_body => 'Invalid JSON data', :code => :bad_request)
    rescue => e
      error "Unknown error: #{e.class}: #{e.message}"
      debug "#{e.class}: #{e}\n#{e.backtrace.join("\n")}"
      msg.confirm!(:response_body => 'Unexpected error encountered', :code => :internal_server_error)
    end
  end

end
