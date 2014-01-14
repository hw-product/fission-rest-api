require 'multi_json'
require 'fission/utils'

Carnivore::PointBuilder.define do

  post %r{/github-commit/?}, :workers => Carnivore::Config.get(:fission, :workers, :github_commit) || 1 do |msg, *args|
    begin
      job_name = Carnivore::Config.get(:fission, :rest_api, :github_commit, :job_name) || :router
      payload = MultiJson.load(msg[:message][:query][:payload] || msg[:message][:body])
      if(filter = msg[:message][:query][:filter])
        debug "Detected pkgr filter on #{msg} - #{filter}"
        unless(File.join('refs/heads', filter) == payload['ref'])
          warn "Discarding #{msg} due to filter match failure. filter: #{filter} ref: #{payload['ref']}"
          msg.confirm!(:response_body => 'Job discared due to filter')
          return # short circuit
        end
      elsif(m[:message][:query][:tags])
        unless(payload['ref'].start_with('refs/tags'))
          warn "Discarding #{msg} due to non tag type event (tag builds enabled). ref: #{payload['ref']}"
          msg.confirm!(:response_body => 'Job discarded due to non-tag type event')
          return # short circuit
        end
      else
        # detect this is a commit push type event
        unless(payload['ref'].start_with('refs/heads'))
          warn "Discarding #{msg} due to non commit type event. ref: #{payload['ref']}"
          msg.confirm!(:response_body => 'Job discarded due to non-commit type event')
          return # short circuit
        end
      end
      payload = Fission::Utils.new_payload(job_name, :github => payload)
      payload[:data][:github_status] = :state => :pending
      debug "Processing payload: #{payload}"
      Fission::Utils.transmit(job_name, payload)
      msg.confirm!(:response_body => 'Job submitted for build')
    rescue MultiJson::DecodeError
      error "Failed to parse JSON from request (#{msg})"
      debug "M: #{msg[:message].inspect}"
      debug "B: #{msg[:message][:body]}"
      debug "Q: #{msg[:message][:query]}"
      debug "Invalid JSON (#{msg}): #{msg[:message][:query][:payload]}"
      msg.confirm!(:response_body => 'Invalid JSON data', :code => :bad_request)
    rescue => e
      error "Unknown error (#{msg}): #{e.class}: #{e.message}"
      debug "#{e.class} (#{msg}): #{e}\n#{e.backtrace.join("\n")}"
      debug "Message contents (#{msg}): #{msg[:message]}"
      msg.confirm!(:response_body => 'Unexpected error encountered', :code => :internal_server_error)
    end
  end

end
