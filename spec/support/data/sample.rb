# frozen_string_literal: true

{
  test_locale_rb: {
    my: {
      inner_key: lambda { |_key| "Dynamic text: #{_key}" }
    }
  }
}