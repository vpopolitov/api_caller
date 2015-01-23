module ApiCaller
  class Service
    class << self
      def decorate_request(route_name = :all, with: ApiCaller::Decorator)
        request_decorators << with.new(route_name)
      end

      def remove_request_decorators
        request_decorators.clear
      end

      def decorate_response(route_name = :all, with: ApiCaller::Decorator)
        response_decorators << with.new(route_name)
      end

      def remove_response_decorators
        response_decorators.clear
      end

      def use_base_url(url)
        @base_url = url
      end

      def use_http_adapter(http_adapter)
        @http_adapter = http_adapter
      end

      def get(url_template, params = {})
        route_name = params[:as]
        raise ApiCaller::Error::MissingRouteName, route_name unless route_name
        routes[route_name] = Route.new template: url_template, http_verb: :get
      end

      def build_request(route_name, params = {})
        route = routes[route_name]
        raise ApiCaller::Error::MissingRoute, route_name unless route

        params = request_decorators.inject(params) { |req, decorator| decorator.execute(req, route_name) }
        context = ApiCaller::Context.new(base_url: base_url, raw_params: params)
        route.build_request(context)
      end

      def build_response(request, message_http_adapter = nil)
        res = (message_http_adapter || http_adapter).send(request.http_verb, request.url) do |_|
          # TODO:: post, put
          #req.params[:q] = 'London,ca'
        end

        res = response_decorators.inject(res) { |res, decorator| decorator.execute(res, :foo) }
        res
      end

      def configure(&block)
        class_eval &block if block_given?
      end

      private

      def routes
        @routes ||= {}
      end

      def base_url
        @base_url ||= ''
      end

      def http_adapter
        @http_adapter ||= ApiCaller::http_adapter || Faraday.new do |builder|
          builder.response :logger
          builder.adapter Faraday.default_adapter
        end
      end

      def request_decorators
        @request_decorators ||= []
      end

      def response_decorators
        @response_decorators ||= []
      end
    end
  end
end