Carnivore::Http::PointBuilder.define do

  post %r{/hook/(v\d+)/([^/+]+)/?(\w+)?/?}, :workers => Carnivore::Config.get(:fission, :workers, :rest_api, :hook) || 1 do |msg, path, version, source, action|
    begin
      data = msg[:message].fetch(
        :query, :payload,
        msg[:message][:body]
      )
      data = data[:payload] if data[:payload]
      hook_payload = [data].flatten(1).first.to_smash
      debug "Payload to process: #{hook_payload.inspect}"
      job_name = Carnivore::Config.fetch(:fission, :rest_api, :hook, :job, action,
        Carnivore::Config.get(:fission, :rest_api, :hook, :job, :default)
      )
      payload = Fission::Utils.new_payload(job_name || 'router')
      payload[:source] = source
      payload.set(
        :data, :rest_api, Smash.new(
          :action => action,
          :params => msg[:message][:query],
          :headers => Smash[msg[:message][:headers].map{|k,v| [k.downcase.tr('-', '_'), v]}]
        )
      )
      payload.set(:data, source, hook_payload)
      debug "Processing payload: #{payload}"
      Fission::Utils.transmit(job_name || :router, payload)
      msg.confirm!(
        :response_body => MultiJson.dump(
          :message => 'Job submitted for processing!',
          :job_id => payload[:message_id]
        )
      )
    rescue MultiJson::DecodeError
      error "Failed to parse JSON from request (#{msg})"
      debug "M: #{msg[:message].inspect}"
      debug "B: #{msg[:message][:body]}"
      debug "Q: #{msg[:message][:query]}"
      debug "Invalid JSON (#{msg}): #{msg[:message][:query][:payload]}"
      msg.confirm!(
        :response_body => MultiJson.dump(
          :error => 'Invalid JSON data'
        ),
        :code => :bad_request
      )
    rescue => e
      error "Unknown error (#{msg}): #{e.class}: #{e.message}"
      debug "#{e.class} (#{msg}): #{e}\n#{e.backtrace.join("\n")}"
      debug "Message contents (#{msg}): #{msg[:message]}"
      msg.confirm!(
        :response_body => MultiJson.dump(
          :error => 'Unexpected error encountered'
        ),
        :code => :internal_server_error
      )
    end
  end

end
