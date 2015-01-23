# name: upverter-permissions
# about: Check Upverter permissions to see if a topic should be accessible.
# version: 0.1
# authors: Ryan Fox

after_initialize do

  TopicGuardian.class_eval do
    alias_method :orig_can_see_topic?, :can_see_topic?

    def can_see_topic?(topic)
      !orig_can_see_topic?(topic)
    end

  end

end
