module ApiCaller
  class Route
    attr_reader :template, :http_verb

    def initialize(params)
      @template = params[:template]
      @http_verb  = params[:http_verb]
    end

    def build_url!(context = {})
      params  = context[:params]
      base_url = context[:base_url]

      route_template = Addressable::Template.new(template)
      url = route_template.expand(params)
      full_url = Addressable::URI.join(base_url, url).to_s

      excluded_params_keys = params.keys.to_symbol_arr - route_template.variables.to_symbol_arr
      # TODO:: change :post, :put to constants
      body = {}
      body = params.select { |k, _| excluded_params_keys.include? k } if [:post, :put].include? @http_verb

      context.http_verb, context.url, context.body = http_verb, full_url, body
    end
  end
end