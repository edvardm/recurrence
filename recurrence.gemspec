Gem::Specification.new do |s|
  s.name = 'recurrence'
  s.version = '0.1.17'
  s.rubygems_version = '1.3.1'
  s.author = 'Edvard Majakari'
  s.email = 'edvard.majakari@adalia.fi'
  #s.date = Date.today.to_s
  s.homepage = 'http://github.com/EdvardM/recurrence/'
  s.platform = Gem::Platform::RUBY
  s.summary = 'Library for periodically recurring things'
  #s.rubyforge_project = 'http://'

  s.files = ["lib/recurrence.rb", "spec/recurrence_spec.rb", "spec/spec_helper.rb"]
  s.require_path = 'lib'
  s.test_file = 'spec/recurrence_spec.rb'
  s.has_rdoc = 'true'
  s.extra_rdoc_files = ['README.textile']
end