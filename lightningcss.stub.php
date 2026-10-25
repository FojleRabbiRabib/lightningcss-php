<?php

/**
 * The public API of the lightningcss extension. Mirrors lightningcss_arginfo.h;
 * the CI arginfo-drift gate regenerates the arginfo bodies from this file and
 * fails on any diff. Class entries and the `Lightningcss\Exception` constants
 * will be registered in C rather than via the stub: the constant values will
 * come from the same status macros as the throw sites, so the declared codes can
 * never drift from the raised ones. Today only the exception class entry is
 * registered (lightningcss_exception.c); the classes and constants declared
 * below land in C with the first processing feature and carry no runtime
 * presence until then. gen_stub therefore runs without class-entry
 * generation and emits arginfo declarations only; the signatures below are
 * the single source for those declarations.
 *
 * Copyright 2026 Fojle Rabbi (Rabib)
 * SPDX-License-Identifier: Apache-2.0
 */

namespace Lightningcss
{
    /**
     * A processing failure. The code is one of the class constants, which are
     * the ABI status codes; the message carries the engine's own detail when
     * it produced one.
     */
    class Exception extends \RuntimeException
    {
        public const int NOT_UTF8 = 1;
        public const int TOO_LARGE = 2;
        public const int PARSE_FAILED = 3;
        public const int INVALID_TARGETS = 4;
        public const int ALLOCATION_FAILED = 5;
        public const int INTERNAL = 6;
    }

    /**
     * Transform options. Every default equals the upstream library default, so
     * `null` options and `new TransformOptions()` are the same request.
     */
    final readonly class TransformOptions
    {
        public bool $minify;
        /** browserslist queries (a list of query strings); null or [] means no targets */
        public ?array $targets;
        public bool $errorRecovery;
        public bool $customMedia;
        public bool $scrollNavigationControls;
        public string $filename;

        public function __construct(
            bool $minify = false,
            ?array $targets = null,
            bool $errorRecovery = false,
            bool $customMedia = false,
            bool $scrollNavigationControls = false,
            string $filename = ''
        ) {
        }
    }

    /**
     * The outcome of a transform. Constructed only by Css::transform(); the
     * private constructor keeps a handle-less instance out of userland.
     */
    final readonly class TransformResult
    {
        public string $code;
        /** upstream warnings (a list of strings); only filled when errorRecovery is on */
        public array $warnings;

        private function __construct()
        {
        }
    }

    final class Css
    {
        /**
         * Parses, downlevels for the given targets, and prints the stylesheet.
         */
        public static function transform(string $css, ?TransformOptions $options = null): TransformResult
        {
        }

        /** The extension version plus the vendored pin, e.g. "0.1.0+lightningcss.1.33.0". */
        public static function version(): string
        {
        }
    }
}
