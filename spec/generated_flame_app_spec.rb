# frozen_string_literal: true

require 'fileutils'
require 'net/http'

RSpec.describe 'Generated Flame app from template' do
	let(:app_name) { 'foo_bar' }

	let(:port) do
		## https://stackoverflow.com/a/5985984/2630849
		socket = Socket.new(:INET, :STREAM, 0)
		socket.bind Addrinfo.tcp('127.0.0.1', 0)
		result = socket.local_address.ip_port
		socket.close
		result
	end

	before do
		`flame_app_generator #{app_name} #{__dir__}/../template`

		Dir.chdir app_name

		Bundler.with_unbundled_env do
			## HACK: https://github.com/dazuma/toys/issues/57
			toys_command = 'truncate_load_path!'
			toys_file_path = '.toys/.toys.rb'
			File.write toys_file_path, File.read(toys_file_path).sub("# #{toys_command}", toys_command)

			## HACK for testing while some server is running
			server_config_file_path = 'config/server.yaml'
			File.write(
				server_config_file_path,
				File.read(server_config_file_path).sub('port: 3000', "port: #{port}")
			)
		end
	end

	after do
		Dir.chdir '..'

		FileUtils.rm_r app_name
	end

	describe 'files' do
		let(:file_path) { self.class.description }

		describe 'content' do
			subject { File.read file_path }

			describe '.toys/.toys.rb' do
				let(:expected_lines) do
					[
						'FB::Application',
						'expand FlameGenerateToys::Template, namespace: FooBar'
					]
				end

				it { is_expected.to include_lines expected_lines }
			end

			describe '.rubocop.yml' do
				let(:expected_lines) do
					[
						'EnforcedStyle: tabs',
						'<% `git status --ignored --porcelain`.lines.grep(/^!! /).each do |path| %>',
						"- <%= path.sub(/^!! /, '') %>",
						'<% end %>'
					]
				end

				it { is_expected.to include_lines expected_lines }
			end

			describe 'README.md' do
				let(:expected_lines) do
					[
						'# FooBar',
						'`createuser -U postgres foo_bar`',
						'*   Add UNIX-user for project: `adduser foo_bar`'
					]
				end

				it { is_expected.to include_lines expected_lines }
			end

			describe 'config.ru' do
				let(:expected_lines) do
					[
						'FB::Application.setup',
						'if FB::Application.config[:session]',
						'use Rack::Session::Cookie, FB::Application.config[:session][:cookie]',
						'use Rack::CommonLogger, FB::Application.logger',
						'FB::App = FB::Application',
						'run FB::Application'
					]
				end

				it { is_expected.to include_lines expected_lines }
			end

			describe 'controllers/site/_controller.rb' do
				let(:expected_lines) do
					[
						'module FooBar',
						'class Controller < FB::Controller'
					]
				end

				it { is_expected.to include_lines expected_lines }
			end

			describe 'spec/integration/spec_helper.rb' do
				let(:expected_lines) do
					[
						'app = FB::Application'
					]
				end

				it { is_expected.to include_lines expected_lines }
			end
		end
	end

	describe 'cleaning directories' do
		subject { Dir.glob('./**/.keep', File::FNM_DOTMATCH) }

		it { is_expected.to be_empty }
	end

	describe 'outdated Node.js packages' do
		subject { system 'pnpm outdated' }

		it { is_expected.to be true }
	end

	describe 'outdated Ruby gems' do
		subject do
			## https://github.com/rubygems/rubygems/issues/6181#issuecomment-1376438133
			Bundler.with_unbundled_env do
				system 'bundle outdated'
			end
		end

		it { is_expected.to be true }
	end

	describe 'Bundler audit' do
		subject do
			Bundler.with_unbundled_env do
				system 'bundle exec bundle-audit check --update'
			end
		end

		it { is_expected.to be true }
	end

	describe 'Node.js lint' do
		subject do
			system 'pnpm lint'
		end

		it { is_expected.to be true }
	end

	describe 'RuboCop lint' do
		subject do
			Bundler.with_unbundled_env do
				system 'bundle exec rubocop'
			end
		end

		it { is_expected.to be true }
	end

	describe 'RSpec test' do
		subject do
			Bundler.with_unbundled_env do
				system 'bundle exec rspec'
			end
		end

		it { is_expected.to be true }
	end

	describe 'working app' do
		subject do
			Bundler.with_unbundled_env do
				puts '!!! spawn'
				pid = spawn 'toys server start'

				puts '!!! detach'
				Process.detach pid

				puts '!!! sleep'
				sleep 0.1

				number_of_attempts = 0

				puts '!!! begin'
				begin
					number_of_attempts += 1
					## https://github.com/gruntjs/grunt-contrib-connect/issues/25#issuecomment-16293494
					response = Net::HTTP.get URI("http://127.0.0.1:#{port}/")
				rescue Errno::ECONNREFUSED => e
					sleep 1
					retry if number_of_attempts < 30
					raise e
				end

				response
			ensure
				Bundler.with_unbundled_env { `toys server stop` }
				begin
					Process.wait pid
				rescue Errno::ECHILD
					## process already stopped
				end
			end
		end

		let(:expected_response_lines) do
			[
				'<title>FooBar</title>',
				'<h1>Hello, world!</h1>'
			]
		end

		it { is_expected.to include_lines expected_response_lines }
	end
end
