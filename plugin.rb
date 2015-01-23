# name: upverter-permissions
# about: Check Upverter permissions to see if a topic should be accessible.
# version: 0.1
# authors: Ryan Fox

after_initialize do

  ApplicationController.class_eval do
    alias_method :orig_ensure_logged_in, :ensure_logged_in

    def ensure_logged_in
      TopicGuardian.cookies = cookies
      orig_ensure_logged_in
    end
  end

  TopicsController.class_eval do
    alias_method :orig_show, :show

    def show
      TopicGuardian.cookies = cookies
      orig_show
    end
  end

  TopicGuardian.class_eval do
    require 'net/http'
    require 'cgi'

    # Add cookies as an instance variable on the class.
    # (As opposed to a class variable, which is apparently different?)
    class << self
      attr_accessor :cookies
    end

    alias_method :orig_can_see_topic?, :can_see_topic?

    def can_see_upverter_design?(design_id)
      def fetch(uri_str, cookie, limit = 10)
        raise ArgumentError, 'HTTP redirect too deep' if limit == 0

        url = URI.parse(uri_str)
        req = Net::HTTP::Get.new(url.path)
        req['Cookie'] = cookie
        response = Net::HTTP.start(url.host, url.port) { |http| http.request(req) }
        case response
        when Net::HTTPRedirection then fetch(response['location'], cookie, limit - 1)
        else
          response
        end
      end

      cookie = CGI::Cookie.new('upverter', TopicGuardian.cookies['upverter']).to_s
      resp = fetch("http://#{SiteSetting.upverter_domain}/dummy/#{design_id}/", cookie)
      return (resp.code == "200")
    end

    def can_see_topic?(topic)
      if !orig_can_see_topic?(topic)
        return can_see_upverter_design?('078648a542739eff')
      end
      return true
    end

  end

end
