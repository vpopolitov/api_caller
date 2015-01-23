describe ApiCaller::Service do
  subject { described_class }

  it { is_expected.to respond_to(:get) }
  # it { is_expected.to respond_to(:post) } ....

  it { is_expected.to respond_to(:build_request) }
  it { is_expected.to respond_to(:build_response) }
  it { is_expected.to respond_to(:configure) }
  it { is_expected.to respond_to(:use_base_url) }
  it { is_expected.to respond_to(:use_http_adapter) }
  it { is_expected.to respond_to(:decorate_request) }
  it { is_expected.to respond_to(:remove_request_decorators) }
  it { is_expected.to respond_to(:decorate_response) }
  it { is_expected.to respond_to(:remove_response_decorators) }

  describe '::build_request' do
    specify 'when route does not registered' do
      expect { described_class.build_request :non_registered_route }.to raise_error(ApiCaller::Error::MissingRoute)
    end

    context 'when route is registered without alias' do
      it { expect{ described_class.get 'url_template' }.to raise_error(ApiCaller::Error::MissingRouteName) }
    end

    context 'when route is registered as get verb' do
      let(:url_template) { 'http://example.com/{first}{?last,third}' }
      let(:request) { described_class.build_request(:test_route, params) }

      before do
        described_class.get url_template, as: :test_route
      end

      it_behaves_like 'a request builder'

      context 'when a request decorator registered' do
        let(:params) { { first: 'first' } }

        let(:fake_req_decorator) do
          Class.new(ApiCaller::Decorator) do
            def wrap(request)
              request.merge!({ last: 'last' })
            end
          end
        end

        around do |example|
          described_class.decorate_request with: fake_req_decorator
          example.run
          described_class.remove_request_decorators
        end

        it 'returns decorated result' do
          expect(request.url).to eq('http://example.com/first?last=last')
        end
      end

      context 'when several request decorators registered' do
        let(:params) { { } }

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

        around do |example|
          described_class.decorate_request with: fake_req_decorator_one
          described_class.decorate_request with: fake_req_decorator_two
          example.run
          described_class.remove_request_decorators
        end

        specify 'all of them are called' do
          expect(request.url).to eq('http://example.com/first?last=last')
        end
      end

      context 'when several request decorators registered with different route names' do
        specify 'registered for given route should be called'
        specify 'registered with :all symbol should be called'
      end
    end

    # context 'when route is registered as post verb' do
    # it 'returns set of parameters which has not been passed to url' do
  end

  describe '::build_response' do
    let(:request) { ApiCaller::Request.new(http_verb: '', url: '') }
    let(:response) { :response }
    let(:decorated_response)  { { body: response } }
    let(:decorated_response2) { { doc: decorated_response } }

    let(:http_adapter) do
      http_adapter = double('http_adapter')
      allow(http_adapter).to receive(:send).and_return(response)
      http_adapter
    end

    context 'when a response decorator registered' do
      let(:fake_res_decorator) do
        Class.new(ApiCaller::Decorator) do
          def wrap(response)
            { body: response }
          end
        end
      end

      before do
        described_class.use_http_adapter http_adapter
        described_class.decorate_response with: fake_res_decorator
      end

      after do
        described_class.remove_response_decorators
        described_class.use_http_adapter nil
      end

      it 'returns decorated result' do
        expect(described_class.build_response request).to eq(decorated_response)
      end
    end

    context 'when several response decorators registered' do
      let(:fake_res_decorator_one) do
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

      before do
        described_class.use_http_adapter http_adapter
        described_class.decorate_response with: fake_res_decorator_one
        described_class.decorate_response with: fake_res_decorator_two
      end

      after do
        described_class.remove_response_decorators
        described_class.use_http_adapter nil
      end

      specify 'all of them are called' do
        expect(described_class.build_response request).to eq(decorated_response2)
      end
    end

    context 'when several response decorators registered with different route names' do
      specify 'registered for given route should be called'
      specify 'registered with :all symbol should be called'
    end
  end

  describe '::configure' do
    let(:request) { described_class.build_request(:test_route, { }) }

    before do
      described_class.get 'url_template', as: :test_route
    end

    context 'when get changed' do
      before do
        described_class.configure { get 'new_url_template', as: :test_route }
      end

      it 'changes preset url value of route' do
        expect(request.url).to eq('new_url_template')
      end
    end

    context 'when base_url changed' do
      before do
        described_class.configure { use_base_url 'http://example.com' }
      end

      it 'changes preset url value of route' do
        expect(request.url).to eq('http://example.com/url_template')
      end
    end
  end

  describe '::base_url' do
    let(:request) { described_class.build_request(:test_route, { }) }

    before do
      described_class.use_base_url 'http://example.com'
      described_class.get 'url_template', as: :test_route
    end

    it 'sets right value of url' do
      expect(request.url).to eq('http://example.com/url_template')
    end
  end

  describe '::decorate' do
    context 'when called with :all symbol' do
      it 'calls decorator ctor with right arguments' do
        expect(ApiCaller::Decorator).to receive(:new).with(:all)
        described_class.decorate_request :all
      end
    end

    context 'when called for given route name' do
      let(:route_name) { :test_route_name }

      it 'calls decorator ctor with right arguments' do
        expect(ApiCaller::Decorator).to receive(:new).with(route_name)
        described_class.decorate_request route_name
      end
    end
  end

  describe '::remove_request_decorators' do
    before do
      @arr = []
      allow(ApiCaller::Service).to receive(:request_decorators).and_return(@arr)
      described_class.decorate_request :route_name
      described_class.remove_request_decorators
    end

    it 'removes specified decorator from registered ones' do
      expect(@arr.size).to eq 0
    end
  end

  describe 'http adapter' do
    let(:mock_http_adapter) do
        http_adapter = double('mock_http_adapter')
        allow(http_adapter).to receive(:send)
        http_adapter
    end

    let(:request) { ApiCaller::Request.new(http_verb: '', url: '') }

    before do
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
        described_class.build_response request
      end
    end

    context 'when adapter registered for caller and for service' do
      before { described_class.use_http_adapter mock_http_adapter }

      specify "call go through service's adapter" do
        expect(mock_http_adapter).to receive(:send).once
        described_class.build_response request
      end
    end

    context 'when adapter registered for caller, service and pass as a parameter' do
      specify "call go through parameter's adapter" do
        expect(mock_http_adapter).to receive(:send).once
        described_class.build_response request, mock_http_adapter
      end
    end
  end
end
