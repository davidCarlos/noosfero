class StoaPlugin::UspUser < ActiveRecord::Base

  establish_connection(:stoa)
  set_table_name('pessoa')

  SALT=YAML::load(File.open(StoaPlugin.root_path + '/config.yml'))['salt']

  alias_attribute :cpf, :numcpf
  alias_attribute :birth_date, :dtanas

  def self.exists?(usp_id)
    StoaPlugin::UspUser.find_by_codpes(usp_id.to_i)
  end

  def self.matches?(usp_id, field, value)
    usp_id.gsub!(/[.-]/,'')
    value.gsub!(/[.-]/,'')
    user = StoaPlugin::UspUser.find_by_codpes(usp_id.to_i)
    return false if user.nil? || !user.respond_to?(field) || value.blank?
    case field.to_sym
    when :cpf
      user.cpf == Digest::MD5.hexdigest(SALT+value.to_i.to_s)
    when :birth_date
      user.birth_date.to_s == value
    end
  end

end
