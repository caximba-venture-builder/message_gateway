class SenderRegistrationService
  def self.call(phone_number:, push_name:, os:)
    Sender.find_or_create_by!(phone_number: phone_number) do |sender|
      sender.push_name = push_name
      sender.os = os
    end
  rescue ActiveRecord::RecordNotUnique
    Sender.find_by!(phone_number: phone_number)
  end
end
