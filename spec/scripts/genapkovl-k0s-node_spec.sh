Describe 'genapkovl-k0s-node.sh'
  # mock chown calls or tests will fail when not run as root
  chown() {
      true
  }

  # avoid downloading 180mb+ release from github
  curl() {
      echo "simulated k0s download"
  }

  Include ./scripts/genapkovl-k0s-node.sh

  Describe 'configure_init_scripts'
    It 'enables cgroups at default runlevels'
      When call configure_init_scripts
      The path "$tmp/etc/runlevels/default/cgroups" should be symlink
    End
  End

  Describe 'install_k0s'
    It 'installs k0s binary for linux/arm/v6 in /usr/local/bin/k0s'
      PLATFORM="linux/arm/v6"
      HL_SSH_KEY_URL="https://somehost/foo.pub"
      Path k0s="$tmp/usr/local/bin/k0s"
      When call install_k0s
      The output should start with "Downloading k0s from URL: https://github.com/k0sproject/k0s/releases/download/"
      The path k0s should be executable
      The contents of file k0s should equal "simulated k0s download"
    End

    It 'installs k0s binary for linux/amd64 in /usr/local/bin/k0s'
      PLATFORM="linux/amd64"
      HL_SSH_KEY_URL="https://somehost/foo.pub"
      Path k0s="$tmp/usr/local/bin/k0s"
      When call install_k0s
      The output should start with "Downloading k0s from URL: https://github.com/k0sproject/k0s/releases/download/"
      The path k0s should be executable
      The contents of file k0s should equal "simulated k0s download"
    End

    It 'fails to install k0s with error for unknown platform'
      PLATFORM="fooarch"
      HL_SSH_KEY_URL="https://somehost/foo.pub"
      When call install_k0s
      The status should be failure
      The error should equal "Unsupported k0s platform: fooarch"
    End
  End
End
