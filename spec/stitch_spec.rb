require 'Typhoeus'
require 'json'
require_relative '../lib/stitch'

describe "Stitch" do
  before(:each) do
    $t0 = Time.now
  end

  def get_value(response)
    JSON.load(response.body).first
  end

  context '.new' do
    it 'should work with no argments' do
      expect{ Stitch.new }.to_not raise_error
    end
  end

  let(:stitch){Stitch.new}

  it 'when calls are dependent' do
    four = sixteen = :unknown
    stitch.context do
      four_response = stitch.get('http://localhost:4567/square/2')
      four = get_value(four_response)
      sixteen_response = stitch.get("http://localhost:4567/square/#{four}")
      sixteen = get_value(sixteen_response)
    end.run

    # sixteen.should == 16
  end

  it 'when calls are independent' do
    four = nine = :unknown
    stitch.context do
      four_response = stitch.get('http://localhost:4567/square/2')
      nine_response = stitch.get('http://localhost:4567/square/3')
      four = get_value(four_response)
      nine = get_value(nine_response)
    end.run

    four.should == 4
    nine.should == 9
  end

  it 'when calls are mixed' do
    Typhoeus::Request.should_receive(:new).with('http://localhost:4567/square/2', method: :get).ordered.and_call_original
    Typhoeus::Request.should_receive(:new).with('http://localhost:4567/square/3', method: :get).ordered.and_call_original
    Typhoeus::Request.should_receive(:new).with('http://localhost:4567/square/4', method: :get).ordered.and_call_original

    four = nine = sixteen = :unknown
    stitch.context do
      four_response = stitch.get('http://localhost:4567/square/2')
      stitch.context do
        four = get_value(four_response)
        sixteen_response = stitch.get("http://localhost:4567/square/#{four}")
        sixteen = get_value(sixteen_response)
      end

      nine_response = stitch.get('http://localhost:4567/square/3')
      nine = get_value(nine_response)
    end.run

    four.should == 4
    nine.should == 9
    sixteen.should == 16
  end

  it 'when calls are mixed in two contexts' do
    Typhoeus::Request.should_receive(:new).with('http://localhost:4567/square/2', method: :get).ordered.and_call_original
    Typhoeus::Request.should_receive(:new).with('http://localhost:4567/square/3', method: :get).ordered.and_call_original
    Typhoeus::Request.should_receive(:new).with('http://localhost:4567/square/4', method: :get).ordered.and_call_original
    Typhoeus::Request.should_receive(:new).with('http://localhost:4567/cube/4', method: :get).ordered.and_call_original

    four = nine = sixteen = sixtyfour = :unknown
    stitch.context do
      four_response = stitch.get('http://localhost:4567/square/2')
      stitch.context do
        four = get_value(four_response)
        sixteen_response = stitch.get("http://localhost:4567/square/#{four}")
        sixteen = get_value(sixteen_response)
      end

      stitch.context do
        four = get_value(four_response)
        sixtyfour_response = stitch.get("http://localhost:4567/cube/#{four}")
        sixtyfour = get_value(sixtyfour_response)
      end

      nine_response = stitch.get('http://localhost:4567/square/3')
      nine = get_value(nine_response)
    end.run

    four.should == 4
    nine.should == 9
    sixtyfour.should == 64
    sixteen.should == 16
  end

  it 'when context is dependent on future from a context at the same level' do
    four = sixteen = twohundredandfiftysix = :unknown
    stitch.context do
      four_response = stitch.get('http://localhost:4567/square/2')
      sixteen_response = stitch.future
      stitch.context do
        four = get_value(four_response)
        sixteen_response.get("http://localhost:4567/square/#{four}")
      end

      stitch.context do
        sixteen = get_value(sixteen_response)
        twohundredandfiftysix_response = stitch.get("http://localhost:4567/square/#{sixteen}")
        twohundredandfiftysix = get_value(twohundredandfiftysix_response)
      end
    end.run

    four.should == 4
    sixteen.should == 16
    twohundredandfiftysix.should == 256
  end

  it 'when context is dependent on two futures' do
    four = nine = big_result = :unknown
    stitch.context do
      four_response = stitch.get('http://localhost:4567/square/2')
      nine_response = stitch.get('http://localhost:4567/square/3')

      stitch.context do
        four = get_value(four_response)
        nine = get_value(nine_response)

        big_result_response = nine_response = stitch.get("http://localhost:4567/square/#{four+nine}")

        big_result = get_value(big_result_response)
      end
    end.run

    four.should == 4
    nine.should == 9
    big_result.should == (4+9)**2
  end
end
