#
# Usage:
#
#   class MyFeature < Spinach::FeatureSteps
#     include Spinach::CurrentUser
#   end
#
module Spinach
  module CurrentUser
    include Spinach::DSL

    def current_user
      # Fabrication
      @current_user ||= FactoryGirl.create :user
    end

    def current_admin_user
      @current_admin_user ||= FactoryGirl.create :admin_user
    end

    step 'I am logged in' do
      login_as(current_user, scope: :user, run_callbacks: false)
    end

    step 'I am logged in as an admin' do
      login_as(current_admin_user, scope: :admin_user, run_callbacks: false)
      visit admin_root_path
      expect(current_path).to eq(admin_root_path)
    end

    step 'I am logged in as a business_user' do
      @current_user = BusinessUser.find_or_initialize_by(:email => 'business@example.com').tap do |user|
        user.name = 'Peter Pan'
        user.password = "password"
        user.password_confirmation = "password"
        user.save unless user.persisted?
      end

      unless @current_user.persisted?
        raise "Coult not create an admin user #{@current_user.email}: #{@current_user.errors.full_messages}"
      end

      if page.all(:css, "a", :text => "Logout").size > 0
        click_link "Logout"
      end

      login_as(current_user, scope: :business_user, run_callbacks: false)
    end

    step 'I have a business' do
      current_user.business = FactoryGirl.create :business
      current_user.save
    end
  end
end
