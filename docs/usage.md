# Using lightningcss-php

This document covers the current extension surface. The CSS processing API
(transform, minify, bundle, source maps) is under active development and is **not yet
present**; nothing in this document promises an API that does not exist.

## Exception type

```php
namespace Lightningcss;

class Exception extends \RuntimeException
{
}
```

Every failure the extension raises extends `Lightningcss\Exception`. Catch it to handle
extension errors specifically while letting unrelated runtime errors propagate:

```php
declare(strict_types=1);

try {
    // extension calls (landing with the processing API)
} catch (\Lightningcss\Exception $e) {
    // extension-specific failure; message is safe to log
}
```

Status codes arrive as class constants together with the shim mapping that raises them;
none exist yet.

## INI setting

| Directive | Default | Range | Purpose |
|---|---|---|---|
| `lightningcss.max_input_bytes` | `16777216` (16 MiB) | `PHP_INI_ALL` | Upper bound on the size of a stylesheet accepted by any processing entry point. Inputs above the bound are rejected before work starts. |

Set globally in `php.ini` or per-call scope with `ini_set()`:

```php
$current = ini_get('lightningcss.max_input_bytes');   // "16777216"
ini_set('lightningcss.max_input_bytes', '33554432');  // 32 MiB
```

## Info surface

```bash
php --ri lightningcss
```

Reports the extension version, the vendored upstream pin (which Lightning CSS revision
this build links), the shim version, and the current INI values.

## Lifecycle contract

The extension has no global mutable state beyond INI values: MINIT registers the INI
entries and the exception class; MSHUTDOWN unregisters them. No resource handles exist
yet, so there is nothing to close or free at the PHP level.
