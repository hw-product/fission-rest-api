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
        if(path.include?('/packages/'))
          s3_store = con_cache[:packages] || Fission::Assets::Store.new
          con_cache[:packages] = s3_store
          path = File.join(Carnivore::Config.get(:fission, :repository_generator, :key_prefix).to_s, path.slice(path.index('packages/'), path.length))
        else
          creds = Carnivore::Config.get(:fission, :repository_publisher, :credentials)
          if(bucket.include?('.'))
            creds = creds.merge(:path_style => true)
            creds.delete(:region)
          end
          s3_store = con_cache[:repository] || Fission::Assets::Store.new(creds.merge(:bucket => bucket))
          con_cache[:repository] = s3_store
          path.sub!(/\/?repository\//, '')
        end
        begin
          streaming = false
          asset = s3_store.get(path.sub(/^\//, '')) do |chunk|
            unless(streaming)
              msg[:message][:request].respond(:ok, :transfer_encoding => :chunked)
              streaming = true
            end
            msg[:message][:request] << chunk
          end
          msg[:message][:request].finish_response
          # NOTE: apt should support 302 headers with Location but it
          # continually errors out :|
#          asset_url = s3_store.url(path.sub(/^\//, ''), 120)
#          warn " --------------> URL: #{asset_url.inspect}"
#          msg.confirm!(:code => :found, 'Location' => asset_url) #s3_store.url(path.sub(/^\//, ''), 120))
          asset.close unless asset.closed?
          asset.delete
          info "Streamed object asset: #{path}"
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
