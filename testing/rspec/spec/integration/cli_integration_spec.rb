require_relative '../../../../environments/rspec_env'
require 'open3'


RSpec.describe 'the Command Line Interface' do

  # A minimal fake test suite that should be available for every spec
  let!(:test_directory) { CukeLinter::FileHelper.create_directory }
  let!(:linted_file) { CukeLinter::FileHelper.create_file(directory: test_directory,
                                                          name:      'lacking_a_description',
                                                          extension: '.feature',
                                                          text:      'Feature:
                                                                        Scenario: A scenario
                                                                          * a step') }

  # Stuff that is not always needed and so can be lazy instantiated
  let(:executable_directory) { "#{PROJECT_ROOT}/exe" }
  let(:executable_name) { 'cuke_linter' }
  let(:executable_path) { "#{executable_directory}/#{executable_name}" }
  let(:results) { std_out, std_err, status = [nil, nil, nil]

                  Dir.chdir(test_directory) do
                    std_out, std_err, status = Open3.capture3(command)
                  end

                  { std_out: std_out, std_err: std_err, status: status } }
  let(:expected_help_text) { ['Usage: cuke_linter [options]',
                              '    -p, --path PATH                The file path that should be linted. Can be a file or directory.',
                              '                                   This option can be specified multiple times in order to lint',
                              '                                   multiple, unconnected locations.',
                              '    -f, --formatter FORMATTER      The formatter used for generating linting output. This option',
                              '                                   can be specified multiple times in order to use more than one',
                              '                                   formatter. Formatters must be specified using their fully',
                              '                                   qualified class name (e.g CukeLinter::PrettyFormatter). Uses',
                              '                                   the default formatter if none are specified.',
                              '    -o, --out OUT                  The file path to which linting results are output. Can be specified',
                              '                                   multiple times. Specified files are matched to formatters in the',
                              '                                   same order that the formatters are specified. Any formatter without',
                              '                                   a corresponding file path will output to STDOUT instead.',
                              '    -r, --require FILEPATH         A file that will be required before further processing. Likely',
                              '                                   needed when using custom linters or formatters in order to ensure',
                              '                                   that the specified classes have been read into memory. This option',
                              '                                   can be specified multiple times in order to load more than one file.',
                              '    -c, --config FILEPATH          The configuration file that will be used. Will use the default',
                              '                                   configuration file (if present) if this option is not specified.',
                              '    -h, --help                     Display the help that you are reading now.',
                              '    -v, --version                  Display the version of the gem being used.',
                              ''].join("\n") }

  context 'with no additional arguments' do

    let(:command) { "bundle exec ruby #{executable_path}" }

    it 'can run cleanly by default' do
      expect(results[:status].exitstatus).to eq(0)
    end

    context 'when the default configuration file exists' do

      before(:each) do
        CukeLinter::FileHelper.create_file(directory: test_directory,
                                           name:      '.cuke_linter',
                                           extension: '',
                                           text:      'FeatureWithoutDescriptionLinter:
                                                         Enabled: false')
      end

      it 'uses the default configuration file by default' do
        expect(results[:std_out]).to include("0 issues found\n")
      end

    end

    context 'when the default configuration file does not exist' do

      before(:each) do
        Dir.chdir(test_directory) do
          FileUtils.rm('./.cuke_linter') if File.exist?('./.cuke_linter')
        end
      end

      it 'can still run cleanly' do
        expect(results[:status].exitstatus).to eq(0)
      end

    end

  end

  describe 'option flags' do

    context 'with a path flag' do
      ['-p', '--path'].each do |path_flag|

        context "using the '#{path_flag}' form" do

          let(:flag) { path_flag }

          context 'with path arguments' do
            let(:file_1) { CukeLinter::FileHelper.create_file(directory: test_directory,
                                                              name:      'some',
                                                              extension: '.feature',
                                                              text:      'Feature:
                                                                          Scenario: A scenario
                                                                            * a step') }
            let(:file_2) { CukeLinter::FileHelper.create_file(directory: test_directory,
                                                              name:      'a_directory/with_a',
                                                              extension: '.feature',
                                                              text:      'Feature:
                                                                          Scenario: A scenario
                                                                            * a step') }
            let(:file_1_path) { file_1 }
            let(:file_2_directory) { File.dirname(file_2) }
            let(:command) { "bundle exec ruby #{executable_path} #{flag} #{file_1_path} #{flag} #{file_2_directory}" }


            it "lints that locations specified by '#{path_flag}'" do
              expect(results[:std_out]).to eq(['FeatureWithoutDescriptionLinter',
                                               '  Feature has no description',
                                               '    <path_to>/a_directory/with_a.feature:1',
                                               '    <path_to>/some.feature:1',
                                               '',
                                               '2 issues found',
                                               ''].join("\n").gsub('<path_to>', test_directory))
            end

          end

          context 'without path arguments' do

            let(:command) { "bundle exec ruby #{executable_path} #{flag}" }


            it 'complains about the missing argument' do
              expect(results[:std_out]).to include("missing argument: #{flag}")
            end

            it 'displays the help text' do
              expect(results[:std_out]).to include(expected_help_text)
            end

            it 'exits with an error' do
              expect(results[:status].exitstatus).to eq(1)
            end

          end

        end
      end
    end

    context 'with a formatter flag' do
      ['-f', '--formatter'].each do |formatter_flag|

        context "using the '#{formatter_flag}' form" do

          let(:flag) { formatter_flag }

          context 'with formatter arguments' do
            let(:linted_file) { CukeLinter::FileHelper.create_file(name:      'some',
                                                                   extension: '.feature',
                                                                   text:      'Feature:
                                                                               Scenario: A scenario
                                                                                 * a step') }
            let(:formatter_class) { 'AFakeFormatter' }
            let(:formatter_class_in_module) { 'CukeLinter::AnotherFakeFormatter' }
            let(:formatter_class_file) { CukeLinter::FileHelper.create_file(extension: '.rb',
                                                                            text:      'class AFakeFormatter
                                                                                        def format(data)
                                                                                          data.reduce("#{self.class}: ") { |final, lint_error| final << "#{lint_error[:problem]}: #{lint_error[:location]}\n" }
                                                                                        end
                                                                                      end') }
            let(:formatter_class_in_module_file) { CukeLinter::FileHelper.create_file(extension: '.rb',
                                                                                      text:      'module CukeLinter
                                                                                                  class AnotherFakeFormatter
                                                                                                    def format(data)
                                                                                                      data.reduce("#{self.class}: ") { |final, lint_error| final << "#{lint_error[:problem]}: #{lint_error[:location]}\n" }
                                                                                                    end
                                                                                                  end
                                                                                                end') }
            let(:command) { "bundle exec ruby #{executable_path} #{flag} #{formatter_class} #{flag} #{formatter_class_in_module} -p #{linted_file} -r #{formatter_class_file} -r #{formatter_class_in_module_file}" }


            it "uses the formatters specified by '#{formatter_flag}'" do
              expect(results[:std_out]).to eq(['AFakeFormatter: Feature has no description: <path_to_file>:1',
                                               'CukeLinter::AnotherFakeFormatter: Feature has no description: <path_to_file>:1',
                                               ''].join("\n").gsub('<path_to_file>', linted_file))
            end

          end

          context 'without formatter arguments' do

            let(:command) { "bundle exec ruby #{executable_path} #{flag}" }


            it 'complains about the missing argument' do
              expect(results[:std_out]).to include("missing argument: #{flag}")
            end

            it 'displays the help text' do
              expect(results[:std_out]).to include(expected_help_text)
            end

            it 'exits with an error' do
              expect(results[:status].exitstatus).to eq(1)
            end

          end

        end
      end
    end

    context 'with an output flag' do
      ['-o', '--out'].each do |output_flag|

        context "using the '#{output_flag}' form" do

          let(:flag) { output_flag }

          context 'with output arguments' do
            let(:output_location) { "#{CukeLinter::FileHelper.create_directory}/output.txt" }
            let(:other_output_location) { "#{CukeLinter::FileHelper.create_directory}/other_output.txt" }
            let(:linted_file) { CukeLinter::FileHelper.create_file(name:      'some',
                                                                   extension: '.feature',
                                                                   text:      'Feature:
                                                                               Scenario: A scenario
                                                                                 * a step') }
            let(:formatter_class_1) { 'AFakeFormatter' }
            let(:formatter_class_2) { 'AnotherFakeFormatter' }
            let(:formatter_class_file) { CukeLinter::FileHelper.create_file(extension: '.rb',
                                                                            text:      'class AFakeFormatter
                                                                                        def format(data)
                                                                                          "Formatting done by #{self.class}"
                                                                                        end
                                                                                      end

                                                                                      class AnotherFakeFormatter
                                                                                        def format(data)
                                                                                          "Formatting done by #{self.class}"
                                                                                        end
                                                                                      end') }
            let(:command) { "bundle exec ruby #{executable_path} -f #{formatter_class_1} -f #{formatter_class_2} #{flag} #{output_location} #{flag} #{other_output_location} -p #{linted_file} -r #{formatter_class_file}" }


            it 'matches output locations to formatters in the same order that they are specified' do
              # Have to trigger the command
              results

              expect(File.read(output_location)).to eq('Formatting done by AFakeFormatter')
              expect(File.read(other_output_location)).to eq('Formatting done by AnotherFakeFormatter')
            end


            context 'with unmatched output arguments' do
              let(:command) { "bundle exec ruby #{executable_path} #{flag} #{output_location} -p #{linted_file}" }


              it "outputs to the location specified by '#{output_flag}'" do
                # Have to trigger the command
                results

                expect(File.read(output_location)).to eq(['FeatureWithoutDescriptionLinter',
                                                          '  Feature has no description',
                                                          '    <path_to_file>:1',
                                                          '',
                                                          '1 issues found'].join("\n").gsub('<path_to_file>', linted_file))
              end

              it 'does not output to STDOUT' do
                expect(results[:std_out]).to eq('')
              end

              it 'uses the default formatter' do
                # Have to trigger the command
                results

                expect(File.read(output_location)).to eq(['FeatureWithoutDescriptionLinter',
                                                          '  Feature has no description',
                                                          '    <path_to_file>:1',
                                                          '',
                                                          '1 issues found'].join("\n").gsub('<path_to_file>', linted_file))
              end

            end

            context 'with unmatched formatter arguments' do
              let(:command) { "bundle exec ruby #{executable_path} #{flag} #{output_location} -f #{formatter_class_1} -f #{formatter_class_2} -p #{linted_file} -r #{formatter_class_file}" }


              it "outputs to the location specified by '#{output_flag}' for the matched formatters" do
                # Have to trigger the command
                results

                expect(File.read(output_location)).to eq("Formatting done by #{formatter_class_1}")
              end

              it 'outputs to STDOUT for the unmatched formatters' do
                expect(results[:std_out]).to eq("Formatting done by #{formatter_class_2}\n")
              end

            end

          end


          context 'without output arguments' do

            let(:command) { "bundle exec ruby #{executable_path} #{flag}" }


            it 'complains about the missing argument' do
              expect(results[:std_out]).to include("missing argument: #{flag}")
            end

            it 'displays the help text' do
              expect(results[:std_out]).to include(expected_help_text)
            end

            it 'exits with an error' do
              expect(results[:status].exitstatus).to eq(1)
            end

          end

        end
      end
    end

    context 'with a require flag' do
      ['-r', '--require'].each do |require_flag|

        context "using the '#{require_flag}' form" do

          let(:flag) { require_flag }

          context 'with require arguments' do
            let(:file_1) { CukeLinter::FileHelper.create_file(extension: '.rb',
                                                              text:      "puts 'This file was loaded'") }
            let(:file_1_path) { file_1 }
            let(:file_2) { CukeLinter::FileHelper.create_file(extension: '.rb',
                                                              text:      "puts 'This file was also loaded'") }
            let(:file_2_path) { file_2 }
            let(:command) { "bundle exec ruby #{executable_path} #{flag} #{file_1_path} #{flag} #{file_2_path}" }


            it "require the files specified by '#{require_flag}' before linting" do
              expect(results[:std_out]).to include('This file was loaded')
              expect(results[:std_out]).to include('This file was also loaded')
            end

          end

          context 'without require arguments' do

            let(:command) { "bundle exec ruby #{executable_path} #{flag}" }


            it 'complains about the missing argument' do
              expect(results[:std_out]).to include("missing argument: #{flag}")
            end

            it 'displays the help text' do
              expect(results[:std_out]).to include(expected_help_text)
            end

            it 'exits with an error' do
              expect(results[:status].exitstatus).to eq(1)
            end

          end

        end
      end
    end

    context 'with a config flag' do
      ['-c', '--config'].each do |config_flag|

        context "using the '#{config_flag}' form" do

          let(:flag) { config_flag }

          context 'with a single config argument' do

            let(:config_file) { CukeLinter::FileHelper.create_file(name:      'my_config_file',
                                                                   extension: '.yml',
                                                                   text:      'FeatureWithoutDescriptionLinter:
                                                                                 Enabled: false') }
            let(:command) { "bundle exec ruby #{executable_path} #{flag} #{config_file}" }

            it "uses the configuration file specified by '#{config_flag}'" do
              expect(results[:std_out]).to include("0 issues found\n")
            end

          end

          context 'with multiple config arguments' do

            let(:command) { "bundle exec ruby #{executable_path} #{flag} foo #{flag} bar" }

            it 'complains that more than one configuration file is specified' do
              expect(results[:std_out]).to eq("Cannot specify more than one configuration file!\n")
            end

            it 'exits with an error' do
              expect(results[:status].exitstatus).to eq(1)
            end

          end

          context 'without config arguments' do

            let(:command) { "bundle exec ruby #{executable_path} #{flag}" }


            it 'complains about the missing argument' do
              expect(results[:std_out]).to include("missing argument: #{flag}")
            end

            it 'displays the help text' do
              expect(results[:std_out]).to include(expected_help_text)
            end

            it 'exits with an error' do
              expect(results[:status].exitstatus).to eq(1)
            end

          end

        end
      end
    end

    context 'with a help flag' do

      let(:command) { "bundle exec ruby #{executable_path} #{flag}" }

      ['-h', '--help'].each do |help_flag|

        context "using the '#{help_flag}' form" do

          let(:flag) { help_flag }

          it "'#{help_flag}' displays the help text" do
            expect(results[:std_out]).to eq(expected_help_text)
          end

          it 'exits cleanly' do
            expect(results[:status].exitstatus).to eq(0)
          end

        end
      end
    end

    context 'with a version flag' do

      let(:command) { "bundle exec ruby #{executable_path} #{flag}" }

      ['-v', '--version'].each do |version_flag|

        context "using the '#{version_flag}' form" do

          let(:flag) { version_flag }

          it "'#{version_flag}' displays the version being used" do
            expect(results[:std_out]).to eq("#{CukeLinter::VERSION}\n")
          end

          it 'exits cleanly' do
            expect(results[:status].exitstatus).to eq(0)
          end

        end
      end
    end

    context 'with an invalid flag' do

      let(:command) { "bundle exec ruby #{executable_path} #{flag}" }
      let(:flag) { '--not_a_real_flag' }

      it 'complains about the invalid flag' do
        expect(results[:std_out]).to include("invalid option: #{flag}")
      end

      it 'displays the help text' do
        expect(results[:std_out]).to include(expected_help_text)
      end

      it 'exits with an error' do
        expect(results[:status].exitstatus).to eq(1)
      end

    end

  end

end