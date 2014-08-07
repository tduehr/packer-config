# Encoding: utf-8
# Copyright 2014 Ian Chesal
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
require 'spec_helper'
require 'fakefs/spec_helpers'

RSpec.describe Packer::Config do
  let(:config_file) { 'config.json'}
  let(:packer) { Packer::Config.new(config_file) }
  let(:builder_type) { Packer::Builder::VIRTUALBOX_ISO }
  let(:provisioner_type) { Packer::Provisioner::FILE }
  let(:postprocessor_type) { Packer::PostProcessor::VAGRANT }
  let(:json_representation) do
    '{"variables":{"foo":"bar"},"builders":[{"type":"virtualbox-iso"}],"provisioners":[{"type":"file"}],"post-processors":[{"type":"vagrant"}]}'
  end

  describe '#initialize' do
    it 'returns an instance' do
      expect(packer).to be_a_kind_of(Packer::Config)
    end
  end

  describe "#validate" do
    it 'returns true for a valid instance' do
      expect(packer.builders).to receive(:length).and_return(1)
      expect(packer.validate).to be_truthy
    end

    it 'raises an error for an invalid instance' do
      expect(packer.builders).to receive(:length).and_return(0)
      expect { packer.validate }.to raise_error
    end
  end

  describe '#dump' do
    it 'dumps a JSON-formatted configuration' do
      packer.add_builder builder_type
      packer.add_provisioner provisioner_type
      packer.add_postprocessor postprocessor_type
      packer.add_variable 'foo', 'bar'
      expect(packer.dump).to eq(json_representation)
    end

    it 'raises an error if the format is not recognized' do
      expect { packer.dump 'invalid-format' }.to raise_error
    end
  end

  describe '#write' do
    it 'writes a JSON-formatted configuration file to disk' do
      packer.add_builder builder_type
      packer.add_provisioner provisioner_type
      packer.add_postprocessor postprocessor_type
      packer.add_variable 'foo', 'bar'
      FakeFS do
        packer.write
        expect(File.read(config_file)).to eq(json_representation)
      end
    end

    it 'raises an error if the format is not recognized' do
      expect { packer.dump 'invalid-format' }.to raise_error
    end
  end

  describe "#build" do
    it 'returns successfully if the build command returns a successful exit code' do
      expect(packer).to receive(:validate).and_return(true)
      expect(packer).to receive(:write).and_return(true)
      open3 = class_double("Open3").as_stubbed_const(:transfer_nested_constants => true)
      expect(open3).to receive(:capture3).and_return(['output', 'error', 0])
      expect(packer.build).to be_truthy
    end

    it 'raises an error if the data is not valid' do
      expect(packer).to receive(:validate).and_raise(Packer::DataObject::DataValidationError)
      expect { packer.build }.to raise_error
    end

    it 'raises an error if the config cannot be written to disk' do
      expect(packer).to receive(:validate).and_return(true)
      expect(packer).to receive(:write).and_raise(StandardError)
      expect { packer.build }.to raise_error
    end

    it 'raises an error if the build command returns an unsuccessful exit code' do
      expect(packer).to receive(:validate).and_return(true)
      expect(packer).to receive(:write).and_return(true)
      open3 = class_double("Open3").as_stubbed_const(:transfer_nested_constants => true)
      expect(open3).to receive(:capture3).and_return(['output', 'error', 1])
      expect { packer.build }.to raise_error
    end
  end

  describe "#add_builder" do
    it 'returns a builder for a valid type' do
      expect(packer.add_builder builder_type).to be_a_kind_of(Packer::Builder)
      expect(packer.builders.length).to eq(1)
      packer.builders = []
    end

    it 'raises an error for an invalid type' do
      expect { packer.add_builder 'invalid' }.to raise_error
      expect(packer.builders.length).to eq(0)
    end
  end

  describe "#add_provisioner" do
    it 'returns a provisioner for a valid type' do
      expect(packer.add_provisioner provisioner_type).to be_a_kind_of(Packer::Provisioner)
      expect(packer.provisioners.length).to eq(1)
      packer.provisioners = []
    end

    it 'raises an error for an invalid type' do
      expect { packer.add_provisioner 'invalid' }.to raise_error
      expect(packer.provisioners.length).to eq(0)
    end
  end

  describe "#add_postprocessor" do
    it 'returns a post-processor for a valid type' do
      expect(packer.add_postprocessor postprocessor_type).to be_a_kind_of(Packer::PostProcessor)
      expect(packer.postprocessors.length).to eq(1)
      packer.postprocessors = []
    end

    it 'raises an error for an invalid type' do
      expect { packer.add_postprocessor 'invalid' }.to raise_error
      expect(packer.postprocessors.length).to eq(0)
    end
  end

  describe '#add_variable' do
    it 'adds a new variable key/value pair' do
      expect(packer.variables).to eq({})
      packer.add_variable('key1', 'value1')
      expect(packer.variables).to eq({'key1' => 'value1'})
      packer.add_variable('key2', 'value2')
      expect(packer.variables).to eq({'key1' => 'value1', 'key2' => 'value2'})
      packer.data['variables'] = {}
    end
  end

  describe '#variable' do
    it 'creates a packer reference to a variable in the configuration' do
      expect(packer.variables).to eq({})
      packer.add_variable('key1', 'value1')
      expect(packer.variable 'key1').to eq('{{user `key1`}}')
      packer.data['variables'] = {}
    end

    it 'raises an error when the variable has not been defined in the configuration' do
      expect(packer.variables).to eq({})
      expect { packer.variable 'key1' }.to raise_error
      packer.data['variables'] = {}
    end
  end

  describe '#envvar' do
    it 'creates a packer reference to an environment variable' do
      expect(packer.envvar 'TEST').to eq('{{env `TEST`}}')
    end
  end

  describe '#macro' do
    it 'creates a packer macro reference' do
      expect(packer.macro 'Var').to eq('{{ .Var }}')
    end
  end

end