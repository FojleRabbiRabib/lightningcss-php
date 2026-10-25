# lightningcss-php — cargo build rules for the Rust shim.
#
# `PHP_ADD_MAKEFILE_FRAGMENT` in config.m4 appends this file into the generated
# Makefile.objects, so a plain `make` builds the shim before the link step
# consumes it. config.m4 substitutes LIGHTNINGCSS_NATIVE_DIR, LIGHTNINGCSS_ARCHIVE,
# LIGHTNINGCSS_CARGO, and LIGHTNINGCSS_CARGO_PROFILE (--release normally, empty
# for the LIGHTNINGCSS_DEBUG=1 profile).
# Copyright 2026 Fojle Rabbi (Rabib)
# SPDX-License-Identifier: Apache-2.0

$(LIGHTNINGCSS_ARCHIVE): $(LIGHTNINGCSS_NATIVE_DIR)/Cargo.toml $(LIGHTNINGCSS_NATIVE_DIR)/Cargo.lock $(wildcard $(LIGHTNINGCSS_NATIVE_DIR)/src/*.rs)
	cd $(LIGHTNINGCSS_NATIVE_DIR) && $(LIGHTNINGCSS_CARGO) build $(LIGHTNINGCSS_CARGO_PROFILE) --locked

# Force the archive to exist before the extension is linked — both the in-tree
# link target and the install copy. The build driver runs cargo itself first,
# so its make never notices, but a cold `make` (rpmbuild, dpkg build, or a
# user's plain phpize flow) races the link against the cargo rule without
# this edge and links a half-built tree.
lightningcss.la: $(LIGHTNINGCSS_ARCHIVE)
$(phplibdir)/lightningcss.la: $(LIGHTNINGCSS_ARCHIVE)
