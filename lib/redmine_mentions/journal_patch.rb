module RedmineMentions
  module JournalPatch
    def self.included(base)
      base.class_eval do
        after_create :send_line
        
        def send_line
          if self.journalized.is_a?(Issue) && self.notes.present?
            issue = self.journalized
            project=self.journalized.project
            users=project.users.to_a.delete_if{|u| (u.type != 'User' || u.mail.empty?)}
            users_regex=users.collect{|u| "#{Setting.plugin_redmine_mentions['trigger']}#{u.login}"}.join('|')
            regex_for_email = '\B('+users_regex+')\b'
            regex = Regexp.new(regex_for_email)
            mentioned_users = self.notes.scan(regex)
            mentioned_users.each do |mentioned_user|
              username = mentioned_user.first[1..-1]
              if user = User.find_by_login(username)
                #MentionMailer.notify_mentioning(issue, self, user).deliver
                send_notification(issue, user)
              begin
              end
            end
          end

          def send_notification(issue, user)
              begin
                journal = self
                Rails.logger.warn("Redmine <-> Line Starting(#{get_channel_key})....M:#{msg}")
                uri = URI('http://bros.focus100.tw/line_notifiers/ext_call')
                get_channel_key = Setting["plugin_redmine_mentions"]["channel_key"]
                get_site_line_token = Setting["plugin_redmine_mentions"]["channel_token"]
                msg = "You are tagged at : #{issue.project.name} - #{issue.tracker.name} - #{issue.id} #{issue.subject} \n\n"
                msg << "#{issue_url(issue)} \n\n"
                msg << "#{issue_url(issue).gsub("http","googlechrome")} \n\n"
                msg << "#{journal.notes} \n\n"
                
                msg << "Tagged by : #{journal.user.login} - #{journal.created_on.to_s(:db)} \n\n"

                params = {:key=>get_channel_key,:message=> msg,:token=>get_site_line_token,:to_user_name=>user.login}

                if Rails.env.production?
                  uri.query = URI.encode_www_form(params)
                  res = Net::HTTP.get_response(uri)
                else
                  Rails.logger.warn("Redmine not in production...notification request not sent.")
                end
                
              rescue Exception => e
                Rails.logger.warn("Redmine <-> Line push notification failed")
                Rails.logger.warn(e)
              end
          end

        end
      end
    end
  end
end
