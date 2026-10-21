class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  around_action :switch_locale

  def default_url_options
    I18n.locale == I18n.default_locale ? {} : { locale: I18n.locale }
  end

  private

  def switch_locale(&action)
    locale = I18n.available_locales.find { |available| available.to_s == params[:locale] }
    I18n.with_locale(locale || I18n.default_locale, &action)
  end
end
