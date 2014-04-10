require 'uri'
require 'base64'
require 'fission/utils'

Carnivore::PointBuilder.define do
  get %r{/repository/.+}, :workers => Carnivore::Config.get(:fission, :workers, :rest_api, :repository) || 1 do |msg, path|
    authorization = msg[:message][:request].headers['Authorization']
    if(authorization)
      acct, token_string = Base64.decode64(authorization.split(' ').last.to_s).split(':')
      token = Fission::Data::Token.find_by_token(token_string)
      bucket = msg[:message][:request].headers['Host'].to_s.split(':').first
      if(token && token.account.name == acct)
        @connections ||= {}
        @connections[Thread.current.object_id] ||= {}
        @connections[Thread.current.object_id][acct] ||= {}
        con_cache = @connections[Thread.current.object_id][acct]
        creds = Carnivore::Config.get(:fission, :repository_publisher, :credentials)
        if(bucket.include?('.'))
          creds = creds.merge(:path_style => true)
          creds.delete(:region)
        end
        s3_store = con_cache[:repository] || Fission::Assets::Store.new(creds.merge(:bucket => bucket))
        con_cache[:repository] = s3_store
        begin
          if(Carnivore::Config.get(:fission, :rest_api, :repository, :stream))
            debug "Streaming repository asset file: #{path}"
            streaming = false
            asset = s3_store.get(path.sub(/^\//, '')) do |chunk|
              unless(streaming)
                msg[:message][:request].respond(:ok, :transfer_encoding => :chunked)
                streaming = true
              end
              msg[:message][:request] << chunk
            end
            msg[:message][:request].finish_response
            asset.close unless asset.closed?
            asset.delete
          else
            debug "Providing remote redirect for repository asset file: #{path}"
            asset_url = s3_store.url(path.sub(/^\//, ''), 120)
            asset_url = URI.parse(asset_url)
            asset_url.host = bucket
            msg.confirm!(:code => :found, 'Location' => asset_url.to_s)
          end
        rescue Fission::Assets::Error::NotFound => e
          warn "Failed to locate requested path: #{e}"
          msg.confirm!(:code => :not_found)
        end
      else
        msg.confirm!(:code => :unauthorized)
      end
    else
      msg.confirm!(:code => :unauthorized, 'WWW-Authenticate' => 'Basic realm="Restricted storage"')
    end
  end
end
