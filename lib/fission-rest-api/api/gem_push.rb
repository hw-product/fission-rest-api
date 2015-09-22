require 'fission'

Carnivore::Http::PointBuilder.define do
  post %r{/gems/api/v1/gems(.*)}, :workers => Carnivore::Config.get(:fission, :workers, :rest_api, :gems) || 1 do |msg, path, action|
    token_string = msg[:message][:request].headers['Authorization']
    if(token_string)
      token = Fission::Data::Token.find_by_token(token_string)
      if(token)
        unless(@asset_store)
          @asset_store = Fission::Assets::Store.new
        end
        key = File.join('gem-push-tmp', "#{Carnivore.uuid}.gem")
        @asset_store.put(key, msg[:message][:body])
        job_name = Carnivore::Config.get(:fission, :rest_api, :gem_push, :job) || 'router'
        data = Smash.new(
          :asset_key => key,
          :account_id => token.account.id
        )
        payload = Fission::Utils.new_payload(job_name || 'router', :gem_push => data)
        if(job_name == 'router')
          payload.set(:data, :router, :action, 'gem_push')
        end
        debug "Processing payload: #{payload}"
        Fission::Utils.transmit(job_name || :router, payload)
        msg.confirm!(
          :response_body => MultiJson.dump(
            :message => 'Gem submitted for publishing!',
            :job_id => payload[:message_id]
          )
        )
      else
        msg.confirm!(:code => :unauthorized)
      end
    else
      msg.confirm!(:code => :unauthorized, 'WWW-Authenticate' => 'Basic realm="Restricted access"')
    end
  end
end
