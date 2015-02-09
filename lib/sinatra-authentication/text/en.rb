module Sinatra
  module SinatraAuthentication
    module Text
      module En
        def self.messages
          {
            :login_ok => "Login successful.",
            :wrong_email_password => "The email or password you entered is incorrect.",
            :logout_ok => "Logout successful.",
            :account_created => "Account created.",
            :account_not_created => "There were some problems creating your account: %{errors}.",
            :account_updated => 'Account updated.',
            :account_not_updated => "Whoops, looks like there were some problems with your updates: %{errors}.",
            :account_deleted => "User deleted.",
            :account_not_deleted => "Deletion failed."
          }
        end
      end
    end
  end
end
