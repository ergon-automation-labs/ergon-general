SCRIPTS_DIRECTORY ?= $(abspath $(CURDIR)/../scripts)
MIX ?= mix

.PHONY: setup help deps test format clean release publish-release setup-hooks push-and-publish logs bump-version compile

help:
	@echo "Bot Army — General-purpose orchestrator"
	@echo "  make setup    - deps + git hooks"
	@echo "  make test"
	@echo "  make release  - prod release (general_purpose_bot)"

setup: deps setup-hooks
	@echo "✓ Setup complete"

setup-hooks:
	@git config core.hooksPath git-hooks
	@echo "✓ Git hooks (core.hooksPath = git-hooks)"

compile:
	@LOG_FILE="/tmp/compile-general-$$(date +%s).log"; \
	echo "Compiling general and logging to $$LOG_FILE..."; \
	$(MIX) compile 2>&1 | tee "$$LOG_FILE"; \
	echo "✓ Compilation log: $$LOG_FILE"

deps:
	$(MIX) deps.get

compile:
	@LOG_FILE="/tmp/compile-general-$$(date +%s).log"; \
	echo "Compiling general and logging to $$LOG_FILE..."; \
	$(MIX) compile 2>&1 | tee "$$LOG_FILE"; \
	echo "✓ Compilation log: $$LOG_FILE"

test:
	$(MIX) test

format:
	$(MIX) format

clean:
	$(MIX) clean
	rm -rf _build cover

release: deps test
	rm -rf _build/prod/rel/general_purpose_bot
	MIX_ENV=prod $(MIX) release general_purpose_bot
	@echo "✓ Release: _build/prod/rel/general_purpose_bot/"

publish-release: release
	@set -e; \
	VERSION=$$(sed -n 's/^[[:space:]]*version:[[:space:]]*"\([^"]*\)".*/\1/p' mix.exs | head -n 1); \
	TARBALL="general_purpose_bot-$$VERSION.tar.gz"; \
	tar -czf "$$TARBALL" -C _build/prod/rel general_purpose_bot/; \
	echo "Created $$TARBALL"; \
	if command -v gh >/dev/null 2>&1; then \
	  if gh release view "v$$VERSION" >/dev/null 2>&1; then \
	    gh release upload "v$$VERSION" "$$TARBALL" --clobber; \
	  else \
	    gh release create "v$$VERSION" "$$TARBALL" \
	      --title "Release v$$VERSION" \
	      --notes "bot_army_general v$$VERSION — general_purpose.ask + operator.complete"; \
	  fi; \
	else \
	  echo "gh not installed; tarball only: $$TARBALL"; \
	fi

push-and-publish:
	@git push && $(MAKE) publish-release

logs:
	@$(SCRIPTS_DIRECTORY)/tail_bot_log.sh

bump-version:
	@if [ -z "$(BUMP)" ]; then echo "Usage: make bump-version BUMP=major|minor|patch"; exit 1; fi
	@OLD=$$(grep 'version:' mix.exs | head -1 | sed -E 's/.*version: "([^"]+)".*/\1/'); \
	bash $(SCRIPTS_DIRECTORY)/bump_version.sh mix.exs $(BUMP) > /dev/null; \
	NEW=$$(grep 'version:' mix.exs | head -1 | sed -E 's/.*version: "([^"]+)".*/\1/'); \
	echo "✓ Bumped: $$OLD → $$NEW"

push: test compile credo
	@echo "✅ All validations passed"
	@echo "$$(date +%s)" > .push-validated
	@echo "✓ Proof-of-validation created"
	@$(MAKE) git-push


git-push:
	@git push origin main 2>&1 | tail -3
