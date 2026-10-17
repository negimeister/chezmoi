alias copy="xclip -selection clipboard"
alias paste="wl-paste --type TEXT"
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles.git/ --work-tree=$HOME'

alias ding="cvlc /usr/share/sounds/freedesktop/stereo/bell.oga --play-and-exit"

alias supermicro="KUBECONFIG=$HOME/.secrets/kubeconfigs/supermicro-new kubectl"
alias hetzner-dev="KUBECONFIG=/home/ngmstr/.secrets/kubeconfigs/hetzner-dev.yaml kubectl"
alias hetzner-sandbox="KUBECONFIG=/home/ngmstr/.secrets/kubeconfigs/hetzner-sandbox.yaml kubectl"
alias hcloud-dev="KUBECONFIG=/home/ngmstr/.secrets/kubeconfigs/hcloud-dev kubectl"
alias hcloud-prod="KUBECONFIG=/home/ngmstr/.secrets/kubeconfigs/hcloud-prod kubectl"
alias hetzner-prod="KUBECONFIG=/home/ngmstr/.config/OpenLens/kubeconfigs/afb6b8fe-ba52-4d89-bf20-7f5189aeec69 kubectl"
alias buildcluster="KUBECONFIG=/home/ngmstr/.secrets/kubeconfigs/buildcluster kubectl"
alias strix="KUBECONFIG=/home/ngmstr/.secrets/kubeconfigs/ai-cluster.yaml kubectl"
alias schlieren="KUBECONFIG=/home/ngmstr/.secrets/kubeconfigs/schlieren.yaml kubectl"
alias box="ssh appuser@code-teto.ubinfra.lan"
