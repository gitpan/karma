
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my @programs_to_install = ('karmad','karmagentd','karmactl');

WriteMakefile(
   NAME          => 'karma',
   VERSION_FROM  => 'karma.pm',
   PL_FILES      => { map {("bin/$_.PL" => "bin/$_")} @programs_to_install },
   EXE_FILES     => [ map {"bin/$_"} @programs_to_install ],
   'clean'       => { FILES => '$(EXE_FILES)' },
   'dist'        => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
);

