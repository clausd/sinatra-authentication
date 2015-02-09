module Sinatra
  module SinatraAuthentication
    module Messages
      module Da
        def self.messages
          {
            :login_ok => "Velkommen.",
            :wrong_email_password => "Brugernavn, email eller password passer ikke.",
            :logout_ok => "Du er logget ud.",
            :account_created => "Bruger oprettet.",
            :account_not_created => "Vi kunne ikke oprette dig: %{errors}.",
            :account_updated => 'Opdateret.',
            :account_not_updated => "Vi kunne ikke gemme dine opdateringer: %{errors}.",
            :account_deleted => "Bruger slettet.",
            :account_not_deleted => "Vi kunne ikke slette brugeren."
          }
        end
      end
    end
  end
end
