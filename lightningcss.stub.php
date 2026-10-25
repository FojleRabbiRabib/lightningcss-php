<?php

/**
 * The public API of the lightningcss extension. Mirrors lightningcss_arginfo.h;
 * the CI arginfo-drift gate regenerates the arginfo bodies from this file and
 * fails on any diff. The exception class is registered in C on purpose and is
 * documented here without @generate-class-entries; functions and option
 * classes land with the first processing feature, each proposed before
 * implementation.
 *
 * Copyright 2026 Fojle Rabbi (Rabib)
 * SPDX-License-Identifier: Apache-2.0
 */

namespace Lightningcss
{
    /**
     * A processing failure. Carries no constants yet: status codes arrive
     * together with the shim mapping that raises them.
     */
    class Exception extends \RuntimeException
    {
    }
}
