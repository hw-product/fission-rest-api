require 'fission'

module Fission
  module RestApi
    module Helpers

      # Parse the requested path into path items
      #
      # @param request_path [String]
      # @return [Hash]
      # @note PATH_PARTS constant _must_ be defined
      def parse_path(request_path)
        request_parts = request_path.split('/').find_all{|i| !i.empty?}
        items = Smash[
          self.class.const_get(:PATH_PARTS).split('/').map do |part|
            unless(part.empty?)
              part.sub(':', '').to_sym
            end
          end.compact.zip(request_parts)
        ]
        remaining = request_parts - items.values
        unless(remaining.empty?)
          items[:_leftover] = remaining.join('/')
        end
        items
      end

      # Lookup account based on token auth provided
      #
      # @param request [Hash]
      # @return [Hash] {:account}
      def token_lookup(request)
        unless(config.fetch(:rest_authentication, true))
          Smash.new(:account_name => :auth_disabled)
        else
          r_token = request.fetch(:authentication, {}).values.detect do |item|
            !item.to_s.empty? && item.to_s != 'd2o-token'
          end
          token = Fission::Data::Models::Token.find_by_token(r_token)
          if(token)
            Smash.new(
              :account_name => token.account.name,
              :account_id => token.account.id
            )
          else
            Smash.new
          end
        end
      end

      # Determine if request is allowed
      #
      # @param request [Hash]
      # @return [TrueClass, FalseClass]
      def is_accessible?(request)
        !token_lookup(request).empty?
      end

    end
  end
end
