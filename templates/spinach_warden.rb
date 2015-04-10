if defined?(Warden)
  Spinach::FeatureSteps.include Warden::Test::Helpers
  Warden.test_mode!

  Spinach.hooks.after_scenario do
    Warden.test_reset!
  end
end
