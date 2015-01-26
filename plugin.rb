# name: upverter-permissions
# about: Check Upverter permissions to see if a topic should be accessible.
# version: 0.2
# authors: Ryan Fox

after_initialize do

  TopicsController.class_eval do
    alias_method :orig_ensure_logged_in, :ensure_logged_in
    def ensure_logged_in
      # This is a horrible thing to do, but it was the least invasive way I could
      # think of to pass in cookies from the controller.
      TopicGuardian.cookies = cookies
      orig_ensure_logged_in
    end

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

      # Use the user's cookie to access the site. They should be logged in because of SSO.
      # This is probably only possible because the forum is in a subdomain of the main site.
      cookie = CGI::Cookie.new('upverter', TopicGuardian.cookies['upverter']).to_s

      resp = fetch("http://#{SiteSetting.upverter_domain}/#{design_id}/check_permissions/", cookie)
      return (resp.code == "200")
    end

    def has_permission_from_upverter?(topic)
      return false unless topic and !topic.deleted_at

      category = SiteSetting.upverter_permissions_category
      category = SiteSetting.embed_category if category == ''
      category_id = Category.find_by(name_lower: category.try(:downcase)).id
      return false unless category_id == topic.category_id

      match = /Design (\w+)$/.match(topic.title)
      if match
        return can_see_upverter_design?(match[1])
      else
        return false
      end
    end

    alias_method :orig_can_see_topic?, :can_see_topic?
    def can_see_topic?(topic)
      if !orig_can_see_topic?(topic)
        return has_permission_from_upverter?(topic)
      end
      return true
    end

    alias_method :orig_can_create_post_on_topic?, :can_create_post_on_topic?
    def can_create_post_on_topic?(topic)
      if !orig_can_create_post_on_topic?(topic)
        return has_permission_from_upverter?(topic)
      end
      return true
    end

  end

  TopicEmbed.class_eval do
    self.singleton_class.send(:alias_method, :orig_find_remote, :find_remote)
    def self.find_remote(url)
      # The default embedder gives crappy results for design pages. Also, many of them won't be
      # accessible to the background process that downloads pages. So I'll just provide a
      # title and initial post contents myself, with useful stuff.
      match = /https?:\/\/#{Regexp.quote(SiteSetting.upverter_domain)}\/([^\/]+?)\/([^\/]+?)\/([^\/]+?)\/?/.match(url)
      if match
        return ["Design #{match[2]}", "<iframe title='test-8' width='800' height='600' scrolling='no' frameborder='0' name='test-8' class='eda_tool' src='https://#{SiteSetting.upverter_domain}/eda/embed/#designId=#{match[2]}'></iframe>\n"]
      else
        return self.orig_find_remote(url)
      end
    end
  end

end
