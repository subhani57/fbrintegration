module ConfirmFormHelper
  # Uses data-fbr-confirm — handled by fbr_confirm_bind.js (Bootstrap modal).
  # Does NOT use data-turbo-confirm (Turbo confirm is unreliable after navigation).
  def confirm_form_data(message)
    return {} if message.blank?

    { fbr_confirm: message }
  end

  def confirm_link_data(message)
    return {} if message.blank?

    { fbr_confirm: message }
  end
end
