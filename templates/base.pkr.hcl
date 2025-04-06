packer {
  required_plugins {
    tart = {
      version = ">= 1.12.0"
      source  = "github.com/cirruslabs/tart"
    }
  }
}

variable "macos_version" {
  type = string
}

source "tart-cli" "tart" {
  vm_base_name = "ghcr.io/cirruslabs/macos-${var.macos_version}-vanilla:latest"
  vm_name      = "${var.macos_version}-base-custom"
  cpu_count    = 4
  memory_gb    = 8
  disk_size_gb = 100
  ssh_password = "admin"
  ssh_username = "admin"
  ssh_timeout  = "120s"
}

build {
  sources = ["source.tart-cli.tart"]

  // System configuration
  provisioner "file" {
    source      = "data/limit.maxfiles.plist"
    destination = "~/limit.maxfiles.plist"
  }

  provisioner "shell" {
    inline = [
      "echo 'Configuring maxfiles...'",
      "sudo mv ~/limit.maxfiles.plist /Library/LaunchDaemons/limit.maxfiles.plist",
      "sudo chown root:wheel /Library/LaunchDaemons/limit.maxfiles.plist",
      "sudo chmod 0644 /Library/LaunchDaemons/limit.maxfiles.plist",
      "echo 'Disabling spotlight...'",
      "sudo mdutil -a -i off",
    ]
  }

  // Install and configure Homebrew
  provisioner "shell" {
    env = {
      HOME_DIR = "/Users/admin"
    }
    inline = [
      "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
      "echo \"export LANG=en_US.UTF-8\" >> ~/.zprofile",
      "echo 'eval \"$(/opt/homebrew/bin/brew shellenv)\"' >> ~/.zprofile"
    ]
  }

  // Configure SSH and GitHub integration
  provisioner "shell" {
    inline = ["mkdir -p ~/.ssh"]
  }

  provisioner "file" {
    source      = "data/github_known_hosts"
    destination = "~/.ssh/known_hosts"
  }

  // Setup for GitHub Actions
  provisioner "shell" {
    script = "scripts/install-actions-runner.sh"
  }

  // Configure browser automation
  provisioner "shell" {
    inline = ["sudo safaridriver --enable"]
  }

  provisioner "shell" {
    script = "scripts/automationmodetool.expect"
  }

  // Verify setup
  provisioner "shell" {
    inline = [
      "source ~/.zprofile",
      "test -f ~/.ssh/known_hosts",
      "brew doctor"
    ]
  }
}
