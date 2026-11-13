fzf_theme_opts="\
--color=bg+:#353a41
--color=bg:#000000
--color=spinner:#e2e2e6
--color=hl:#ffb4ab
--color=fg:#e2e2e6
--color=header:#ffb4ab
--color=info:#a1c9fe
--color=pointer:#e2e2e6
--color=marker:#c2c7d0
--color=fg+:#e2e2e6
--color=prompt:#a1c9fe
--color=hl+:#ffb4ab
--color=selected-bg:#42474f
--color=border:#42474f
--color=label:#e2e2e6"

export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:+$FZF_DEFAULT_OPTS
}$fzf_theme_opts"
