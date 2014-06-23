require 'multi_json'
require 'fission'

Carnivore::Http::PointBuilder.define do

  post %r{/v1/github/?(\w+)?/?}, :workers => Carnivore::Config.get(:fission, :workers, :rest_api, :github) || 1 do |msg, path, action|
    begin
      action = action.tr('/', '').to_sym
      data = msg[:message][:query][:payload] ||
        msg[:message][:body].is_a?(Hash) ? msg[:message][:body][:payload] : msg[:message][:body]
      payloads = MultiJson.load(data)
      payload = [payloads].flatten(1).first.to_smash
      debug "Payload to process: #{payload.inspect}"
      payload[:github_event] = msg[:message][:headers]['X-GitHub-Event']
      payload[:github_delivery] = msg[:message][:headers]['X-GitHub-Delivery']
      job_name = Carnivore::Config.get(:fission, :rest_api, :github, :job, action) ||
        Carnivore::Config.get(:fission, :rest_api, :github, :job, :default)
      valid = [].tap do |results|
        if(filter = msg[:message][:query][:filter])
          results.push payload[:ref].end_with?(filter)
        end
        if(msg[:message][:query][:tags])
          results.push (payload[:ref].start_with?('refs/tags') || payload[:ref_type] == 'tag') && !payload[:deleted]
        end
      end
      valid.push(true) if valid.empty? && job_name
      if(valid.include?(true))
        payload = Fission::Utils.new_payload(job_name || 'router', :github => payload)
        payload[:source] = :github
        payload[:data][:github_status] = {:state => :pending}
        payload[:data][:router] = {:action => action}
        debug "Processing payload: #{payload}"
        Fission::Utils.transmit(job_name || :router, payload)
        msg.confirm!(
          :response_body => MultiJson.dump(
            :message => 'Job submitted for processing!',
            :job_id => payload[:message_id]
          )
        )
      else
        msg.confirm!(
          :response_body => MutliJson.dump(
            :message => 'Job discarded due to filter'
          )
        )
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

  post %r{/github-commit/?(\w+)?/?}, :workers => Carnivore::Config.get(:fission, :workers, :rest_api, :github_commit) || 1 do |msg, path, action|
    begin
      if(action)
        action = action.gsub('/', '').to_sym
      end
      job_name = Carnivore::Config.get(:fission, :rest_api, :github_commit, :job_name) || :router
      data = msg[:message][:query][:payload] ||
        msg[:message][:body].is_a?(Hash) ? msg[:message][:body][:payload] : msg[:message][:body]
      payloads = MultiJson.load(data)
      payload = [payloads].flatten(1).first.to_smash
      payload[:source] = :github
      payload[:github_event] = msg[:message][:headers]['X-GitHub-Event']
      payload[:github_delivery] = msg[:message][:headers]['X-GitHub-Delivery']
      debug "Payload to process: #{payload.inspect}"
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
        if(payload['ref'].start_with?('refs/tags') || payload['ref_type'] == 'tag')
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
        payload[:source] = :github
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
