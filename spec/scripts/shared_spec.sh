Describe 'shared.sh'
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
End
