require 'sinatra/base'
require File.expand_path("../models/abstract_user", __FILE__)
require File.expand_path("../sinatra-authentication/text/en.rb", __FILE__)
require File.expand_path("../sinatra-authentication/text/da.rb", __FILE__)

module Sinatra
  module SinatraAuthentication
    def self.registered(app)
      #INVESTIGATE
      #the possibility of sinatra having an array of view_paths to load from
      #PROBLEM
      #sinatra 9.1.1 doesn't have multiple view capability anywhere
      #so to get around I have to do it totally manually by
      #loading the view from this path into a string and rendering it
      unless defined?(app.settings.sinatra_authentication_view_path)
        app.set :sinatra_authentication_view_path, File.expand_path('../views/', __FILE__)
      end
      unless defined?(app.settings.template_engine)
        app.set :template_engine, :haml
      end
      unless defined?(app.settings.sinatra_authentication_messages)
        app.set :sinatra_authentication_messages, Text::En.messages
      end

      app.get '/users/?' do
        login_required
        redirect "/" unless current_user.admin?

        @users = User.all
        if @users != []
          send settings.template_engine, get_view_as_string("index.#{settings.template_engine}"), :layout => use_layout?
        else
          redirect '/signup'
        end
      end

      app.get '/users/:id/?' do
        login_required

        if params[:id].to_i != current_user.id and !current_user.admin?
          redirect "/"
        end
        @user = User.get(:id => params[:id])
        send settings.template_engine,  get_view_as_string("show.#{settings.template_engine}"), :layout => use_layout?
      end

      #convenience for ajax but maybe entirely stupid and unnecesary
      app.get '/logged_in' do
        if session[:user]
          "true"
        else
          "false"
        end
      end

      app.get '/login/?' do
        if session[:user]
          redirect '/'
        else
          send settings.template_engine, get_view_as_string("login.#{settings.template_engine}"), :layout => use_layout?
        end
      end

      app.post '/login/?' do
        email_or_name = params[:email] || params[:name] || params[:email_or_name]
        if user = User.authenticate(email_or_name, params[:password]) || User.authenticate_by_name(email_or_name, params[:password])
          session[:user] = user.id

          if Rack.const_defined?('Flash')
            flash[:notice] = settings.sinatra_authentication_messages[:login_ok]
          end

          if session[:return_to]
            redirect_url = session[:return_to]
            session[:return_to] = false
            redirect redirect_url
          else
            redirect '/'
          end
        else
          if Rack.const_defined?('Flash')
            flash[:error] = settings.sinatra_authentication_messages[:wrong_email_password]
          end
          redirect '/login'
        end
      end

      app.get '/logout/?' do
        session[:user] = nil
        if Rack.const_defined?('Flash')
          flash[:notice] = settings.sinatra_authentication_messages[:logout_ok]
        end
        return_to = ( session[:return_to] ? session[:return_to] : '/' )
        redirect return_to
      end

      app.get '/signup/?' do
        if session[:user]
          redirect '/'
        else
          send settings.template_engine, get_view_as_string("signup.#{settings.template_engine}"), :layout => use_layout?
        end
      end

      app.post '/signup/?' do
        user_data = params[:user].select {|k| k != :permission_level}
        @user = User.set(user_data)
        if @user.valid && @user.id
          session[:user] = @user.id
          if Rack.const_defined?('Flash')
            flash[:notice] = settings.sinatra_authentication_messages[:account_created]
          end
          redirect '/'
        else
          if Rack.const_defined?('Flash')
            flash[:error] = settings.sinatra_authentication_messages[:account_not_created] % {:errors => @user.errors}
          end
          redirect '/signup?' + hash_to_query_string(params['user'])
        end
      end

      app.get '/users/:id/edit/?' do
        login_required
        redirect "/users" unless current_user.admin? || current_user.id.to_s == params[:id]
        @user = User.get(:id => params[:id])
        send settings.template_engine, get_view_as_string("edit.#{settings.template_engine}"), :layout => use_layout?
      end

      app.post '/users/:id/edit/?' do
        login_required
        redirect "/users" unless current_user.admin? || current_user.id.to_s == params[:id]

        user = User.get(:id => params[:id])
        user_attributes = params[:user]
        if params[:user][:password] == ""
            user_attributes.delete("password")
            user_attributes.delete("password_confirmation")
        end

        if user.update(user_attributes)
          if Rack.const_defined?('Flash')
            flash[:notice] = settings.sinatra_authentication_messages[:account_updated]
          end
          redirect '/'
        else
          if Rack.const_defined?('Flash')
            flash[:error] = settings.sinatra_authentication_messages[:account_not_updated] % {:errors => user.errors}
          end
          redirect "/users/#{user.id}/edit?" + hash_to_query_string(user_attributes)
        end
      end

      app.get '/users/:id/delete/?' do
        login_required
        redirect "/users" unless current_user.admin? || current_user.id.to_s == params[:id]

        if User.delete(params[:id])
          if Rack.const_defined?('Flash')
            flash[:notice] = account_updated[:account_deleted]
          end
        else
          if Rack.const_defined?('Flash')
            flash[:error] = account_updated[:account_not_deleted]
          end
        end
        redirect '/'
      end


      if Sinatra.const_defined?('FacebookObject')
        app.get '/connect/?' do
          if fb[:user]
            if current_user.class != GuestUser
              user = current_user
            else
              user = User.get(:fb_uid => fb[:user])
            end

            if user
              if !user.fb_uid || user.fb_uid != fb[:user]
                user.update :fb_uid => fb[:user]
              end
              session[:user] = user.id
            else
              user = User.set!(:fb_uid => fb[:user])
              session[:user] = user.id
            end
          end
          redirect '/'
        end

        app.get '/receiver' do
          %[<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
            <html xmlns="http://www.w3.org/1999/xhtml" >
              <body>
                <script src="http://static.ak.connect.facebook.com/js/api_lib/v0.4/XdCommReceiver.js" type="text/javascript"></script>
              </body>
            </html>]
        end
      end
    end
  end

  module Helpers
    def hash_to_query_string(hash)
      hash.collect {|k,v| "#{k}=#{v}"}.join('&')
    end

    def login_required
      #not as efficient as checking the session. but this inits the fb_user if they are logged in
      user = current_user
      if user && user.class != GuestUser
        return true
      else
        session[:return_to] = request.fullpath
        redirect '/login'
        return false
      end
    end

    def current_user
      if session[:user]
        User.get(:id => session[:user])
      else
        GuestUser.new
      end
    end

    def logged_in?
      !!session[:user]
    end

    def use_layout?
      !request.xhr?
    end

    #BECAUSE sinatra 9.1.1 can't load views from different paths properly
    def get_view_as_string(filename)
      view = File.join(settings.sinatra_authentication_view_path, filename)
      data = ""
      f = File.open(view, "r")
      f.each_line do |line|
        data += line
      end
      return data
    end

    def render_login_logout(html_attributes = {:class => ""})
    css_classes = html_attributes.delete(:class)
    parameters = ''
    html_attributes.each_pair do |attribute, value|
      parameters += "#{attribute}=\"#{value}\" "
    end

      result = "<div id='sinatra-authentication-login-logout' >"
      if logged_in?
        logout_parameters = html_attributes
        # a tad janky?
        logout_parameters.delete(:rel)
        result += "<a href='/users/#{current_user.id}/edit' class='#{css_classes} sinatra-authentication-edit' #{parameters}>Edit account</a> "
        if Sinatra.const_defined?('FacebookObject')
          if fb[:user]
            result += "<a href='javascript:FB.Connect.logoutAndRedirect(\"/logout\");' class='#{css_classes} sinatra-authentication-logout' #{logout_parameters}>Logout</a>"
          else
            result += "<a href='/logout' class='#{css_classes} sinatra-authentication-logout' #{logout_parameters}>Logout</a>"
          end
        else
          result += "<a href='/logout' class='#{css_classes} sinatra-authentication-logout' #{logout_parameters}>Logout</a>"
        end
      else
        result += "<a href='/signup' class='#{css_classes} sinatra-authentication-signup' #{parameters}>Signup</a> "
        result += "<a href='/login' class='#{css_classes} sinatra-authentication-login' #{parameters}>Login</a>"
      end

      result += "</div>"
    end

    if Sinatra.const_defined?('FacebookObject')
      def render_facebook_connect_link(text = 'Login using facebook', options = {:size => 'small'})
          if options[:size] == 'small'
            size = 'Small'
          elsif options[:size] == 'medium'
            size = 'Medium'
          elsif options[:size] == 'large'
            size = 'Large'
          elsif options[:size] == 'xlarge'
            size = 'BigPun'
          else
            size = 'Small'
          end

          %[<a href="#" onclick="FB.Connect.requireSession(function(){document.location = '/connect';}); return false;" class="fbconnect_login_button FBConnectButton FBConnectButton_#{size}">
              <span id="RES_ID_fb_login_text" class="FBConnectButton_Text">
                #{text}
              </span>
            </a>]
      end
    end
  end

  register SinatraAuthentication
end

class GuestUser
  def guest?
    true
  end

  def permission_level
    0
  end

  # current_user.admin? returns false. current_user.has_a_baby? returns false.
  # (which is a bit of an assumption I suppose)
  def method_missing(m, *args)
    return false
  end
end
