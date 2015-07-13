require 'fission-rest-api'

module Fission
  module RestApi

    class Repository < Fission::Callback

      PATH_PARTS = ':action'

      include Fission::RestApi::Helpers

      # Determine validity of message
      #
      # @param message [Carnivore::Message]
      # @return [TrueClass]
      def valid?(message)
        super do |_|
          # only care that it's an HTTP request
          message[:message][:request] &&
            message[:message][:connection]
        end
      end

      # Process request and return result
      #
      # @param message [Carnviore::Message]
      def execute(message)
        failure_wrap(message) do |_|
          info = token_lookup(message[:message])
          if(!info.empty? && info[:account_name])
            path = parse_path(message[:message][:request].path)
            if(info[:account_name] == :auth_disabled)
              asset_key = File.join('published-repositories', path[:_leftover].to_s)
            else
              asset_key = File.join('published-repositories', info[:account_name], path[:_leftover].to_s)
            end
            info "Processing repository request for `#{info[:account_name]}` for item: #{asset_key}"
            begin
              if(true) #config.get(:repository, :stream))
                debug "Delivery of asset `#{asset_key}` via stream"
                begin
                  message[:message][:request].respond(:ok, :transfer_encoding => :chunked)
                  sleep(0.3)
                  asset_store.get(asset_key) do |chunk|
                    message[:message][:request] << chunk
                  end
                ensure
                  message[:message][:request].finish_response
                  message[:message][:connection].close
                  message[:message][:confirmed] = true
                end
              else
                debug "Delivery of asset `#{asset_key}` via 302 redirect"
                message.confirm!(
                  :code => :found,
                  'Location' => asset_store.url(asset_key)
                )
              end
            rescue Jackal::Assets::Error::NotFound
              message.confirm!(
                :code => :not_found,
                :response_body => 'File not found!'
              )
            end
          else
            if(message[:message][:authentication].empty?)
              info "Access denied for request (no credentials provided): #{message[:message][:connection].remote_addr} to #{message[:message][:request].path}"
              message.confirm!(
                :code => :unauthorized,
                'WWW-Authenticate' => 'Basic realm="Restricted storage"',
                :response_body => 'Access denied! [credentials required]'
              )
            else
              info "Access denied for request (invalid credentials): #{message[:message][:connection].remote_addr} to #{message[:message][:request].path}"
              message.confirm!(:code => :unauthorized, :response_body => 'Access denied! [invalid credentials]')
            end
          end
        end
      end

    end
  end
end

Fission.register(:rest_api, :repository, Fission::RestApi::Repository)
