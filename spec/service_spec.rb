describe ApiCaller::Service do
  let(:mock_http_adapter) do
    http_adapter = double('mock_http_adapter')
    allow(http_adapter).to receive(:send).and_return('')
    http_adapter
  end

  before { described_class.use_http_adapter mock_http_adapter }

  subject { described_class }

  it { is_expected.to respond_to(:get) }
  # it { is_expected.to respond_to(:post) } ....

  it { is_expected.to respond_to(:call) }
  it { is_expected.to respond_to(:configure) }
  it { is_expected.to respond_to(:use_base_url) }
  it { is_expected.to respond_to(:use_http_adapter) }
  it { is_expected.to respond_to(:decorate_request) }
  it { is_expected.to respond_to(:remove_request_decorators) }
  it { is_expected.to respond_to(:decorate_response) }
  it { is_expected.to respond_to(:remove_response_decorators) }

  describe '::call' do
    specify 'when route does not registered' do
      expect { described_class.call :non_registered_route }.to raise_error(ApiCaller::Error::MissingRoute)
    end

    context 'when route is registered without alias' do
      it { expect{ described_class.get 'url_template' }.to raise_error(ApiCaller::Error::MissingRouteName) }
    end

    context 'when route is registered as get verb' do
      let(:url_template) { 'http://example.com/{first}{?last,third}' }

      before do
        described_class.get url_template, as: :test_route
      end

      specify 'http request will be sent to the proper url' do
        expect(mock_http_adapter).to receive(:send).with(:get, 'http://example.com/first')
        described_class.call(:test_route, first: :first)
      end

      describe 'request decorator' do
        let(:fake_req_decorator_one) do
          Class.new(ApiCaller::Decorator) do
            def wrap(request)
              request.merge!({ first: 'first' })
            end
          end
        end

        let(:fake_req_decorator_two) do
          Class.new(ApiCaller::Decorator) do
            def wrap(request)
              request.merge!({ last: 'last' })
            end
          end
        end

        context 'when a request decorator registered' do
          let(:params) { { first: 'first' } }

          around do |example|
            described_class.decorate_request with: fake_req_decorator_two
            example.run
            described_class.remove_request_decorators
          end

          it 'returns decorated result' do
            expect(mock_http_adapter).to receive(:send).with(:get, 'http://example.com/first?last=last')
            described_class.call(:test_route, params)
          end
        end

        context 'when several request decorators registered' do
          let(:params) { { } }

          context 'with all routes' do
            around do |example|
              described_class.decorate_request with: fake_req_decorator_one
              described_class.decorate_request with: fake_req_decorator_two
              example.run
              described_class.remove_request_decorators
            end

            specify 'all of them are called' do
              expect(mock_http_adapter).to receive(:send).with(:get, 'http://example.com/first?last=last')
              described_class.call(:test_route, params)
            end
          end

          context 'with different route names' do
            around do |example|
              described_class.decorate_request :test_route, with: fake_req_decorator_one
              described_class.decorate_request :fake_route, with: fake_req_decorator_two
              example.run
              described_class.remove_request_decorators
            end

            specify 'registered for given route should be called' do
              expect(mock_http_adapter).to receive(:send).with(:get, 'http://example.com/first')
              described_class.call(:test_route, params)
            end
          end
        end
      end

      describe 'response decorator' do
        let(:decorated_response)  { { body: '' } }
        let(:decorated_response2) { { doc: decorated_response } }
        let(:response) { described_class.call :test_route }

        let(:fake_res_decorator) do
          Class.new(ApiCaller::Decorator) do
            def wrap(response)
              { body: response }
            end
          end
        end

        let(:fake_res_decorator_two) do
          Class.new(ApiCaller::Decorator) do
            def wrap(response)
              { doc: response }
            end
          end
        end

        context 'when a response decorator registered' do
          around do |example|
            described_class.decorate_response with: fake_res_decorator
            example.run
            described_class.remove_response_decorators
          end

          it 'returns decorated result' do
            expect(response).to eq(decorated_response)
          end
        end

        context 'when several response decorators registered' do
          context 'with all routes' do
            around do |example|
              described_class.decorate_response with: fake_res_decorator
              described_class.decorate_response with: fake_res_decorator_two
              example.run
              described_class.remove_response_decorators
            end

            specify 'all of them are called' do
              expect(response).to eq(decorated_response2)
            end
          end

          context 'with different route names' do
            around do |example|
              described_class.decorate_response :test_route, with: fake_res_decorator
              described_class.decorate_response :fake_route, with: fake_res_decorator_two
              example.run
              described_class.remove_response_decorators
            end

            specify 'registered for given route should be called' do
              expect(response).to eq(decorated_response)
            end
          end
        end
      end
    end

    # context 'when route is registered as post verb' do
    # it 'returns set of parameters which has not been passed to url' do
  end

  describe '::configure' do
    let(:base_url) { 'http://example.com' }

    before do
      described_class.use_base_url base_url
      described_class.get 'url_template', as: :test_route
    end

    context 'when get changed' do
      before { described_class.configure { get 'new_url_template', as: :test_route } }
      it 'changes preset url value of route' do
        expect(mock_http_adapter).to receive(:send).with(:get, "#{base_url}/new_url_template")
        described_class.call :test_route
      end
    end

    context 'when base_url changed' do
      let(:new_base_url) { 'http://example.com' }

      before do
        url = new_base_url
        described_class.configure { use_base_url url }
      end

      it 'changes preset url value of route' do
        expect(mock_http_adapter).to receive(:send).with(:get, "#{new_base_url}/url_template")
        described_class.call :test_route
      end
    end
  end

  describe '::base_url' do
    let(:base_url) { 'http://example.com' }

    before do
      described_class.use_base_url base_url
      described_class.get 'url_template', as: :test_route
    end

    it 'sets right value of url' do
      expect(mock_http_adapter).to receive(:send).with(:get, "#{base_url}/url_template")
      described_class.call :test_route
    end
  end

  describe '::decorate_request' do
    context 'when called with :all symbol' do
      after { described_class.remove_request_decorators }

      it 'calls decorator ctor with right arguments' do
        expect(ApiCaller::Decorator).to receive(:new).with(:all).and_call_original
        described_class.decorate_request :all
      end
    end

    context 'when called for given route name' do
      let(:route_name) { :test_route_name }

      after { described_class.remove_request_decorators }

      it 'calls decorator ctor with right arguments' do
        expect(ApiCaller::Decorator).to receive(:new).with(route_name).and_call_original
        described_class.decorate_request route_name
      end
    end
  end

  describe '::remove_request_decorators' do
    context 'with default parameter' do
      before do
        @arr = []
        allow(ApiCaller::Service).to receive(:request_decorators).and_return(@arr)
        described_class.decorate_request :route_name_one
        described_class.decorate_request :route_name_two
        described_class.remove_request_decorators
      end

      it 'removes all decorators from registered ones' do
        expect(@arr.size).to eq 0
      end
    end

    context 'with passed parameter' do
      before do
        @arr = []
        allow(ApiCaller::Service).to receive(:request_decorators).and_return(@arr)
        described_class.decorate_request :route_name_one
        described_class.decorate_request :route_name_two
        described_class.remove_request_decorators :route_name_one
      end

      it 'removes specified decorator from registered ones' do
        expect(@arr.size).to eq 1
        expect(@arr[0].route_name).to eq :route_name_two
      end
    end
  end

  describe '::decorate_response' do
    context 'when called with :all symbol' do
      after { described_class.remove_response_decorators }

      it 'calls decorator ctor with right arguments' do
        expect(ApiCaller::Decorator).to receive(:new).with(:all).and_call_original
        described_class.decorate_response :all
      end
    end

    context 'when called for given route name' do
      let(:route_name) { :test_route_name }

      after { described_class.remove_response_decorators }

      it 'calls decorator ctor with right arguments' do
        expect(ApiCaller::Decorator).to receive(:new).with(route_name).and_call_original
        described_class.decorate_response route_name
      end
    end
  end

  describe '::remove_response_decorators' do
    context 'with default parameter' do
      before do
        @arr = []
        allow(ApiCaller::Service).to receive(:response_decorators).and_return(@arr)
        described_class.decorate_response :route_name_one
        described_class.decorate_response :route_name_two
        described_class.remove_response_decorators
      end

      it 'removes all decorators from registered ones' do
        expect(@arr.size).to eq 0
      end
    end

    context 'with passed parameter' do
      before do
        @arr = []
        allow(ApiCaller::Service).to receive(:response_decorators).and_return(@arr)
        described_class.decorate_response :route_name_one
        described_class.decorate_response :route_name_two
        described_class.remove_response_decorators :route_name_one
      end

      it 'removes specified decorator from registered ones' do
        expect(@arr.size).to eq 1
        expect(@arr[0].route_name).to eq :route_name_two
      end
    end
  end

  describe 'http adapter' do
    before do
      described_class.get 'url_template', as: :test_route
      ApiCaller.use_http_adapter nil
      described_class.use_http_adapter nil
    end

    after do
      ApiCaller.use_http_adapter nil
      described_class.use_http_adapter nil
    end

    context 'when adapter registered for caller' do
      before { ApiCaller.use_http_adapter mock_http_adapter }

      specify "call go through caller's adapter" do
        expect(mock_http_adapter).to receive(:send)
        described_class.call :test_route
      end
    end

    context 'when adapter registered for caller and for service' do
      before { described_class.use_http_adapter mock_http_adapter }

      specify "call go through service's adapter" do
        expect(mock_http_adapter).to receive(:send).once
        described_class.call :test_route
      end
    end

    context 'when adapter registered for caller, service and pass as a parameter' do
      specify "call go through parameter's adapter" do
        expect(mock_http_adapter).to receive(:send).once
        described_class.call :test_route, {}, mock_http_adapter
      end
    end
  end
end
