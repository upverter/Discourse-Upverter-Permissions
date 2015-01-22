# name: upverter-permissions
# about: Check Upverter permissions to see if a topic should be accessible.
# version: 0.1
# authors: Ryan Fox

after_initialize do

  TopicGuardian.class_eval do
    def can_see_topic?(topic)
      return false unless topic
      # Admins can see everything
      return true if is_admin?
      # Deleted topics
      return false if topic.deleted_at && !can_see_deleted_topics?

      raise "this is me testing!"

      if topic.private_message?
        return authenticated? &&
          topic.all_allowed_users.where(id: @user.id).exists?
      end

      # not secure, or I can see it
      !topic.read_restricted_category? || can_see_category?(topic.category)

    end

end
