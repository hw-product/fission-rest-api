require 'fission/utils'

Carnivore::PointBuilder.define do

  get %r{/package/(\w+)/(.+?)/(\w+\.\w+)}, :workers => Carnivore::Config.get(:fission, :workers, :rest_api_packages) || 1 do |msg, acct_name, package_name|
    begin
      if(defined?(Fission::Utils.enabled?(:data)))
        # validate and bail if we don't have what we want
        abort RuntimeError.new('No validation token provided with request') unless params[:token]
        act = Fission::Data::Account.find_by_name(acct_name)
        abort NameError.new("Failed to locate account (#{acct_name})") unless act
        abort RuntimeError.new('Invalid validation token provided') unless act.tokens.include?(params[:token])
        unless(@store)
          @store = Fission::Assets::Store.new
        end
        bucket = Carnivore::Config.get(:fission, :package_builder, :storage_bucket)
        key = File.join(acct_name, package_name)
        url = @store.url(bucket, key)
        msg.confirm!(:response_body => {Location: url}, :code => :found)
      else
        abort NotImplementedError.new('Data support is not enabled. Unable to perform lookups!')
      end
    rescue => e
      error "Unknown error (#{msg}): #{e.class}: #{e.message}"
      debug "#{e.class} (#{msg}): #{e}\n#{e.backtrace.join("\n")}"
      debug "Message contents (#{msg}): #{msg[:message]}"
      msg.confirm!(:response_body => 'Unexpected error encountered', :code => :internal_server_error)
    end
  end
end
