require 'json'

class DataContract
  def initialize(params)      
    params.each do |k,v|
      next unless @fields.include?(k.to_s)
      accessor = "#{k.to_s}=".to_sym
      if self.respond_to? accessor
        self.send(accessor, v)
      else
        var = "@#{k.to_s}".to_sym
        instance_variable_set(var, v)
      end
    end
  end

  def to_json
    hsh = {}
    @fields.each do |field|
      key = "@#{field}".to_sym
      value = instance_variable_get(key)
      hsh[key] = value
    end
    JSON.generate(hsh)
  end
end
