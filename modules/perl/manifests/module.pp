# perl::module{ 'File::Rsync::Mirror::Recent':
#}

# Specific projects should use carton/cpanfile.
# This is for bootstraping and other things that
# can not use Carton easily.

define perl::module (
    $ensure   = 'present',
    $module   = $name,
    $version  = '0',
    $perl_version = hiera('perl::version', '5.22.2'),
) {

    require stdlib

    ensure_resource('perl::build', $perl_version )

    $bin_dir = "/opt/perl-${perl_version}/bin"
    $perldoc = "${bin_dir}/perldoc"
    $cpanm = "${bin_dir}/cpanm"

    exec { "perl_module_${name}":
        command     => "${cpanm} -n ${module}~${version}",
        cwd         => '/tmp',
        path        => [$bin_dir, '/bin', '/usr/bin', '/usr/local/bin'],
        timeout     => 300,
        require     => [
            Exec["perl_cpanm_${perl_version}"],
            File['/opt'],
        ],
        unless      => "${bin_dir}/perl -c '-M${module} ${version}' -e1",
    }
}