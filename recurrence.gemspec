Gem::Specification.new do |s|
  s.name = 'recurrence'
  s.version = GEM_VERSION
  s.author = 'Edvard Majakari'
  s.email = 'edvard.majakari@adalia.fi'
  #s.homepage = 
  s.platform = Gem::Platform::RUBY
  s.summary = 'Library for periodically recurring things'

  s.files = FileList["{doc,lib,spec}/**/*"].exclude('rdoc').to_a
  s.require_path = 'lib'
  s.test_file = 'spec/recurrence_spec.rb'
  s.has_rdoc = 'true'
  s.extra_rdoc_files = ['README']
end