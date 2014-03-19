require 'multi_json'
require 'fission/utils'

Carnivore::PointBuilder.define do

  post %r{/github-commit/?(\w+)?/?}, :workers => Carnivore::Config.get(:fission, :workers, :rest_api, :github_commit) || 1 do |msg, path, action|
    begin
      if(action)
        action = action.gsub('/', '').to_sym
      end
      job_name = Carnivore::Config.get(:fission, :rest_api, :github_commit, :job_name) || :router
      payload = MultiJson.load(msg[:message][:query][:payload] || msg[:message][:body])
      valid = []
      if(filter = msg[:message][:query][:filter])
        debug "Detected pkgr filter on #{msg} - #{filter}"
        if(File.join('refs/heads', filter) == payload['ref'])
          valid << true
        else
          warn "Filter match failure on #{msg}. filter: #{filter} ref: #{payload['ref']}"
        end
      end
      if(msg[:message][:query][:tags])
        if(payload['ref'].start_with?('refs/tags'))
          if(payload['deleted'] == true)
            warn "Tag match failure #{msg} due to tag destruction type event (tag builds enabled). ref: #{payload['ref']}"
          else
            valid << true
          end
        else
          warn "Tag match failure #{msg} due to non tag type event (tag builds enabled). ref: #{payload['ref']}"
        end
      end
      if(valid.empty?)
        # detect this is a commit push type event
        unless(payload['ref'].start_with?('refs/heads'))
          warn "Commit match failure on #{msg} due to non commit type event. ref: #{payload['ref']}"
        else
          valid << true
        end
      end
      if(valid.include?(true))
        payload = Fission::Utils.new_payload(job_name, :github => payload)
        payload[:data][:github_status] = {:state => :pending}
        payload[:data][:router] = {:action => action}
        debug "Processing payload: #{payload}"
        Fission::Utils.transmit(job_name, payload)
        msg.confirm!(:response_body => 'Job submitted for processing!')
      else
        msg.confirm!(:response_body => 'Job discarded due to filter')
      end
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
