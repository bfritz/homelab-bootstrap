Describe 'shared.sh'
  # mock chown calls or tests will fail when not run as root
  chown() {
      true
  }

  Describe 'initialization'
    Include ./scripts/shared.sh

    It 'defines $tmp'
      The variable tmp should be defined
      The variable tmp should start with "/tmp/tmp."
    End

    It 'creates $tmp directory'
      The path $tmp should be directory
    End
  End

  Describe 'add_ssh_key'
    Include ./scripts/shared.sh

    It 'always creates /root directory'
      When call add_ssh_key
      The path $tmp/root should be directory
    End

    It 'does not create .ssh directory without HL_SSH_KEY_URL defined'
      HL_SSH_KEY_URL=""
      When call add_ssh_key
      The path $tmp/root/.ssh should not be exist
    End

    curl() {
        echo "ssh-rsa AAAAB3Nza= foo@bar.com"
    }

    It 'creates .ssh/authorized_key file with HL_SSH_KEY_URL defined'
      HL_SSH_KEY_URL="https://somehost/foo.pub"
      When call add_ssh_key
      The path $tmp/root/.ssh should be exist
      The path $tmp/root/.ssh/authorized_keys should be file
      The contents of file  $tmp/root/.ssh/authorized_keys should equal "ssh-rsa AAAAB3Nza= foo@bar.com"
    End
  End

  Describe 'add_vector'
    Include ./scripts/shared.sh

    # simulate download of a vector release tarball, e.g.
    # https://packages.timber.io/vector/0.17.3/vector-0.17.3-armv7-unknown-linux-musleabihf.tar.gz
    curl() {
        tmpdir=$(mktemp -d)
        mkdir "$tmpdir"/ignored

        mkdir "$tmpdir"/ignored/config
        touch "$tmpdir"/ignored/config/vector.toml

        mkdir "$tmpdir"/ignored/bin
        touch "$tmpdir"/ignored/bin/vector

        tar -C "$tmpdir" -cz ./ignored
        rm -r "$tmpdir"
    }

    It 'creates /usr/local/bin/vector'
      When call add_vector 0.88.99 armv7-unknown-linux-gnueabihf
      The output should start with "Downloading vector from URL: https://packages.timber.io/vector/0.88.99/vector-0.88.99-"
      The path $tmp/usr/local/bin/vector should be exist
      The path $tmp/usr/local/bin/vector should be executable
    End

    It 'creates /var/lib/vector'
      When call add_vector 0.88.99 armv7-unknown-linux-gnueabihf
      The output should start with "Downloading vector from URL: https://packages.timber.io/vector/0.88.99/vector-0.88.99-"
      The path $tmp/var/lib/vector should be exist
      The path $tmp/var/lib/vector should be a directory
    End
  End
End
