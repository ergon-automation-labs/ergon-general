SCRIPTS_DIRECTORY ?= $(abspath $(CURDIR)/../scripts)
MIX ?= mix

.PHONY: setup help deps test format clean release publish-release setup-hooks push-and-publish logs

help:
	@echo "Bot Army — General (fleet filesystem skills)"
	@echo "  make setup    - deps + git hooks"
	@echo "  make test"
	@echo "  make release  - prod release (general_bot)"

setup: deps setup-hooks
	@echo "✓ Setup complete"

setup-hooks:
	@git config core.hooksPath git-hooks
	@echo "✓ Git hooks (core.hooksPath = git-hooks)"

deps:
	$(MIX) deps.get

test:
	$(MIX) test

format:
	$(MIX) format

clean:
	$(MIX) clean
	rm -rf _build cover

release: deps test
	rm -rf _build/prod/rel/general_bot
	MIX_ENV=prod $(MIX) release
	@echo "✓ Release: _build/prod/rel/general_bot/"

publish-release: release
	@set -e; \
	VERSION=$$(sed -n 's/^[[:space:]]*version:[[:space:]]*"\([^"]*\)".*/\1/p' mix.exs | head -n 1); \
	TARBALL="general_bot-$$VERSION.tar.gz"; \
	tar -czf "$$TARBALL" -C _build/prod/rel general_bot/; \
	echo "Created $$TARBALL"; \
	if command -v gh >/dev/null 2>&1; then \
	  if gh release view "v$$VERSION" >/dev/null 2>&1; then \
	    gh release upload "v$$VERSION" "$$TARBALL" --clobber; \
	  else \
	    gh release create "v$$VERSION" "$$TARBALL" \
	      --title "Release v$$VERSION" \
	      --notes "bot_army_general v$$VERSION — NATS skill.list / skill.get"; \
	  fi; \
	else \
	  echo "gh not installed; tarball only: $$TARBALL"; \
	fi

push-and-publish:
	@git push && $(MAKE) publish-release

logs:
	@$(SCRIPTS_DIRECTORY)/tail_bot_log.sh
